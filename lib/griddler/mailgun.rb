require 'griddler'
require 'griddler/mailgun/version'
require 'griddler/mailgun/adapter'

# normalizers
require 'griddler/mailgun/normalizers/vendor_specific'

module Griddler
  module Mailgun
  end
end

Griddler.adapter_registry.register(:mailgun, Griddler::Mailgun::Adapter)
