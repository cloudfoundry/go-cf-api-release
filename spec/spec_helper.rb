# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'bosh/template'

DEFAULT_CCDB_LINK = Bosh::Template::Test::Link.new(
  name: 'cloud_controller_db',
  properties: {
    'ccdb' => {
      'db_scheme' => 'postgres'
    }
  }
)
