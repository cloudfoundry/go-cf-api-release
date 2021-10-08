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
  let(:ccinternal_link) do
    Bosh::Template::Test::Link.new(
      name: 'cloud_controller_internal',
      properties: {
        'system_domain' => 'example.com',
        'cc' => {
          'external_host' => 'api',
          'external_protocol' => 'https'
        },
      }
    )
  end

  describe 'database configuration' do
    subject(:rendering) { YAML.safe_load(template.render({}, consumes: [ccdb_link, ccinternal_link]))['db'] }
    context 'db_scheme is postgres' do
      it { is_expected.to include('connection_string' => 'host=db.example.com port=1234 user=admin_user dbname=ccdb password=admin_password sslmode=disable') }
    end

    context 'db_scheme is mysql' do
      let(:ccdb_config) { super().merge({ 'db_scheme' => 'mysql' }) }
      it { is_expected.to include('connection_string' => 'admin_user:admin_password@tcp(db.example.com:1234)/ccdb?tls=false&parseTime=true') }
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
    let(:uaa_config) do
      {
        'ca_cert' => <<~EOCERT
          --- BEGIN CERT ---
          cert contents
          --- END CERT ---
        EOCERT
      }
    end
    subject(:rendering) { YAML.safe_load(template.render({ 'uaa' => uaa_config }, consumes: [ccdb_link, ccinternal_link]))['uaa'] }

    context 'defaults are used' do
      it { is_expected.to include('url' => 'https://uaa.service.cf.internal:8443') }
    end

    context 'url and port are provided' do
      let(:uaa_config) do
        super().merge({ 'internal_url' => 'custom.uaa.hostname', 'tls_port' => 8888 })
      end
      it { is_expected.to include('url' => 'https://custom.uaa.hostname:8888') }
    end

    context 'ca_cert is provided' do
      it { is_expected.to include('client' => { 'tls_config' => { 'ca_file' => '/var/vcap/jobs/cloud-controller/tls/uaa/ca.crt' } }) }
    end
  end


  describe 'cc info configuration' do
    let(:cc_config) { {} }
    subject(:rendering) { YAML.safe_load(template.render(cc_config, consumes: [ccdb_link, ccinternal_link]))['info'] }

    context 'defaults are used' do
      it { is_expected.to include('name' => '') }
      it { is_expected.to include('build' => '') }
      it { is_expected.to include('support_address' => '') }
      it { is_expected.to include('version' => 0) }
      it { is_expected.to include('description' => '') }
    end

    context 'info is provided' do
      let(:cc_config) do
        super().merge({
          'name' => 'test',
          'build'  => 'custom',
          'support_address' => 'help@example.com',
          'version' => 1,
          'description' => 'test',
        })
      end
      it { is_expected.to include('name' => 'test') }
      it { is_expected.to include('build' => 'custom') }
      it { is_expected.to include('support_address' => 'help@example.com') }
      it { is_expected.to include('version' => 1) }
      it { is_expected.to include('description' => 'test') }
    end
  end

  describe 'cc configuration' do
    subject(:rendering) { YAML.safe_load(template.render( {}, consumes: [ccdb_link, ccinternal_link])) }

    context 'link provides properties' do
      it { is_expected.to include('external_domain' => 'api.example.com') }
      it { is_expected.to include('external_protocol' => 'https') }
    end
  end
end
