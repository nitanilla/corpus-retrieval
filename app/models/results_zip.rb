class ResultsZip
  include Mongoid::Document
  include Mongoid::Timestamps

  class StatusDoesNotExist < StandardError; end

  STATUSES = %i[processing finished failed waiting]
  TYPES = %w[readmes]
  MAX_STORED = 10

  field :query, type: String
  field :filename, type: String
  field :zip, type: BSON::Binary
  field :type, type: String
  field :worker_id, type: String
  field :status, type: Integer, default: STATUSES.index(:waiting)

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
    self.update_attributes! zip: zip, status: self.class.status_of(:finished)
    self.class.where(query: self.query, :id.ne => self.id).destroy_all
  end

  def zip_to_download
    zip && zip.data
  end

  def status_name
    STATUSES[self.status]
  end

  def finished?
    self.status == self.class.status_of(:finished)
  end
end
