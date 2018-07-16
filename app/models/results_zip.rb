class ResultsZip
  include Mongoid::Document
  include Mongoid::Timestamps

  class StatusDoesNotExist < StandardError; end

  STATUSES = %i[processing finished failed waiting]
  TYPES = %w[readmes issues]
  MAX_STORED = 10
  CHARS_PER_CHUNK = 14.megabytes

  field :query, type: String
  field :filename, type: String
  field :type, type: String
  field :worker_id, type: String
  field :status, type: Integer, default: STATUSES.index(:waiting)

  has_many :zip_chunks, dependent: :destroy

  validates :type,
    presence: true,
    inclusion: {in: TYPES}

  def self.destroy_olds!
    (self.all.sort_by(&:created_at).to_a[0..(MAX_STORED*-1-1)] || []).each(&:destroy)
  end

  def self.status_of(status_symbol)
    inx = STATUSES.index(status_symbol)
    (inx >= 0) ? inx : (raise StatusDoesNotExist, status_symbol.inspect)
  end

  def finish!(zip)
    self.zip_chunks.delete_all
    zip_size = zip.size
    chunks_amount = (zip_size/CHARS_PER_CHUNK.to_f).ceil.to_i
    for i in 0...chunks_amount
      self.zip_chunks.create!(binary: BSON::Binary.new(zip[(CHARS_PER_CHUNK*i)...(CHARS_PER_CHUNK*(i+1))]))
    end
    self.update_attributes! status: self.class.status_of(:finished)
    self.class.where(query: self.query, type: self.type, :id.ne => self.id).destroy_all
  end

  def zip_to_download
    self.zip_chunks.order(created_at: :asc).to_a.map{|c| c.binary.data}.join
  end

  def status_name
    STATUSES[self.status]
  end

  def finished?
    self.status == self.class.status_of(:finished)
  end
end
