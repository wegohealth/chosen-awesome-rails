module Chosen
  module Rails
  end
end

require 'chosen-awesome-rails/version'

case ::Rails.version.to_s
  when /^4|5|6|7/
    require 'chosen-awesome-rails/engine'
  when /^3\.[12]/
    require 'chosen-awesome-rails/engine3'
end
