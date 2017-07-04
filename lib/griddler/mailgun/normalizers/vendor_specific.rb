class VendorSpecific
  def self.normalize(params)
    new(params).normalize
  end

  def initialize(params)
    @params = params
  end

  def normalize

  end
end
