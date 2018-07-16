class ZipChunk
  include Mongoid::Document
  include Mongoid::Timestamps
  belongs_to :results_zip

  field :binary, type: BSON::Binary
end
