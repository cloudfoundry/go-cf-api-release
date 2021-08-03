require 'rspec'
require 'bosh/template/test'
require 'bosh/template'

describe 'cloud-controller' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  describe 'bpm.yml' do
    let(:template) { job.template('config/bpm.yml') }

    it 'uses the psql binary when ccdb.db_scheme is postgres' do
      process = get_process_from_bpm(YAML.safe_load(template.render({})), job_name)
      expect(process['executable']).to eq '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-psql'
    end

    it 'uses the mysql binary when ccdb.db_scheme is mysql' do
      config = { 'ccdb' => { 'db_scheme' => 'mysql' } }
      process = get_process_from_bpm(YAML.safe_load(template.render(config)), job_name)
      expect(process['executable']).to eq '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-mysql'
    end

    it 'raises an error if ccdb.db_scheme is not postgres or mysql' do
      config = { 'ccdb' => { 'db_scheme' => 'foo' } }
      expect { template.render(config) }.to raise_error('ccdb.db_scheme foo is not supported')
    end

    it 'passes the config file path to the binary' do
      process = get_process_from_bpm(YAML.safe_load(template.render({})), job_name)
      expect(process['args']).to eq ['/var/vcap/jobs/cloud-controller/config/cloud-controller.yml']
    end
  end

  describe 'cloud-controller.yml' do
    let(:template) { job.template('config/cloud-controller.yml') }
    let(:default_ccdb_config) do
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

    it 'creates a psql connection string' do
      config_file = YAML.safe_load(template.render({ 'ccdb' => default_ccdb_config }))
      expect(config_file['db']['connectionstring']).to eq 'host=db.example.com port=1234 user=admin_user dbname=ccdb password=admin_password sslmode=disable'
    end

    it 'creates a mysql connection string' do
      ccdb_config = default_ccdb_config.merge({ 'db_scheme' => 'mysql' })
      config_file = YAML.safe_load(template.render({ 'ccdb' => ccdb_config }))
      expect(config_file['db']['connectionstring']).to eq 'admin_user:admin_password@tcp(db.example.com:1234)/ccdb?tls=false&parseTime=true'
    end

    it 'raises an error when address is not set' do
      ccdb_config = default_ccdb_config.reject { |k, _| k == 'address' }
      expect { template.render({ 'ccdb' => ccdb_config }) }.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"ccdb.address\"]'")
    end

    it 'raises an error when port is not set' do
      ccdb_config = default_ccdb_config.reject { |k, _| k == 'port' }
      expect { template.render({ 'ccdb' => ccdb_config }) }.to raise_error(Bosh::Template::UnknownProperty, "Can't find property '[\"ccdb.port\"]'")
    end
  end
end

def get_process_from_bpm(bpm_config, job_name)
  bpm_config['processes'].select { |p| p['name'] == job_name }.first
end
