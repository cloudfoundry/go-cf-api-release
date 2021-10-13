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
        }
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
                        'build' => 'custom',
                        'support_address' => 'help@example.com',
                        'version' => 1,
                        'description' => 'test'
                      })
      end
      it { is_expected.to include('name' => 'test') }
      it { is_expected.to include('build' => 'custom') }
      it { is_expected.to include('support_address' => 'help@example.com') }
      it { is_expected.to include('version' => 1) }
      it { is_expected.to include('description' => 'test') }
    end
  end

  describe 'cc urls configuration' do
    subject(:rendering) { YAML.safe_load(template.render(cc_config, consumes: [ccdb_link, ccinternal_link]))['urls'] }

    context 'uses defaults based on system_domain from link' do
      let(:cc_config) { {} }
      it { is_expected.to include('log_cache' => 'https://log-cache.example.com') }
      it { is_expected.to include('log_stream' => 'https://log-stream.example.com') }
      it { is_expected.to include('doppler' => 'wss://doppler.example.com:443') }
      it { is_expected.to include('login' => 'https://login.example.com') }
      it { is_expected.to include('uaa' => 'https://uaa.example.com') }
    end

    context 'doppler config is provided' do
      let(:cc_config) { { 'doppler' => { 'use_ssl' => false, 'port' => 4443 } } }
      it { is_expected.to include('doppler' => 'ws://doppler.example.com:4443') }
    end

    context 'login is disabled' do
      let(:cc_config) { { 'login' => { 'enabled' => false } } }
      it { is_expected.to include('login' => 'https://uaa.example.com') }
    end

    context 'login protocol is provided' do
      let(:cc_config) { { 'login' => { 'protocol' => 'http' } } }
      it { is_expected.to include('login' => 'http://login.example.com') }
    end

    context 'login url is provided' do
      let(:cc_config) { { 'login' => { 'url' => 'https://custom.login.url' } } }
      it { is_expected.to include('login' => 'https://custom.login.url') }
    end

    context 'uaa url is provided' do
      let(:cc_config) { { 'login' => { 'enabled' => false }, 'uaa' => { 'url' => 'https://custom.uaa.url' } } }
      it { is_expected.to include('login' => 'https://custom.uaa.url') }
      it { is_expected.to include('uaa' => 'https://custom.uaa.url') }
    end
  end

  describe 'cc app_ssh configuration' do
    subject(:rendering) { YAML.safe_load(template.render(cc_config, consumes: [ccdb_link, ccinternal_link]))['app_ssh'] }

    context 'uses defaults based on system_domain from link' do
      let(:cc_config) { {} }
      it { is_expected.to include('endpoint' => 'ssh.example.com:2222') }
      it { is_expected.to include('oauth_client' => 'ssh-proxy') }
      it { is_expected.to include('host_key_fingerprint' => nil) }
    end

    context 'port is provided' do
      let(:cc_config) { { 'app_ssh' => { 'port' => 22 } } }
      it { is_expected.to include('endpoint' => 'ssh.example.com:22') }
    end

    context 'oauth_client_id is provided' do
      let(:cc_config) { { 'app_ssh' => { 'oauth_client_id' => 'custom-client-id' } } }
      it { is_expected.to include('oauth_client' => 'custom-client-id') }
    end

    context 'host_key_fingerprint is provided' do
      let(:cc_config) { { 'app_ssh' => { 'host_key_fingerprint' => 'b8:80:2c:8c:d7:25:ad:2a:b4:8c:02:34:52:06:f7:ba:1f:0d:02:de' } } }
      it { is_expected.to include('host_key_fingerprint' => 'b8:80:2c:8c:d7:25:ad:2a:b4:8c:02:34:52:06:f7:ba:1f:0d:02:de') }
    end
  end

  describe 'cc configuration' do
    subject(:rendering) { YAML.safe_load(template.render({}, consumes: [ccdb_link, ccinternal_link])) }

    context 'link provides properties' do
      it { is_expected.to include('external_domain' => 'api.example.com') }
      it { is_expected.to include('external_protocol' => 'https') }
    end
  end
end
