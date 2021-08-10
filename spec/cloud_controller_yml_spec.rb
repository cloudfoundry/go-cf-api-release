# frozen_string_literal: true

require_relative 'spec_helper'

describe 'cloud-controller' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  let(:template) { job.template('config/cloud-controller.yml') }
  let(:ccdb_config) do
    {
      'db_scheme' => 'postgres',
      'address' => 'db.example.com',
      'port' => 1234,
      'databases' => [{
        'name' => 'ccdb', 'tag' => 'cc'
      }],
      'roles' => [{
        'name' => 'admin_user', 'password' => 'admin_password', 'tag' => 'admin'
      }]
    }
  end
  let(:ccdb_link) do
    Bosh::Template::Test::Link.new(
      name: 'cloud_controller_db',
      properties: {
        'ccdb' => ccdb_config
      }
    )
  end

  describe 'database configuration' do
    subject(:rendering) { YAML.safe_load(template.render({}, consumes: [ccdb_link]))['db'] }
    context 'db_scheme is postgres' do
      it { is_expected.to include('connectionstring' => 'host=db.example.com port=1234 user=admin_user dbname=ccdb password=admin_password sslmode=disable') }
    end

    context 'db_scheme is mysql' do
      let(:ccdb_config) { super().merge({ 'db_scheme' => 'mysql' }) }
      it { is_expected.to include('connectionstring' => 'admin_user:admin_password@tcp(db.example.com:1234)/ccdb?tls=false&parseTime=true') }
    end

    context 'missing address property' do
      let(:ccdb_config) { super().reject { |k, _| k == 'address' } }

      it 'raises an error' do
        expect { rendering }.to raise_error(KeyError, 'key not found: "address"')
      end
    end

    context 'missing port property' do
      let(:ccdb_config) { super().reject { |k, _| k == 'port' } }

      it 'raises an error' do
        expect { rendering }.to raise_error(KeyError, 'key not found: "port"')
      end
    end
  end

  describe 'uaa configuration' do
    let(:uaa_config) { {} }
    subject(:rendering) { YAML.safe_load(template.render({ 'uaa' => uaa_config }, consumes: [ccdb_link]))['uaa'] }

    context 'defaults are used' do
      it { is_expected.to include('url' => 'https://uaa.service.cf.internal:8443') }
    end

    context 'url and port are provided' do
      let(:uaa_config) do
        {
          'internal_url' => 'custom.uaa.hostname',
          'tls_port' => 8888
        }
      end
      it { is_expected.to include('url' => 'https://custom.uaa.hostname:8888') }
    end
  end
end
