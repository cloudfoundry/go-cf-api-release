require 'rspec'
require 'bosh/template/test'
require 'bosh/template'

describe 'cloud-controller' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  let(:ccdb_config) { { 'db_scheme' => 'postgres' } }
  let(:ccdb_link) do
    Bosh::Template::Test::Link.new(
      name: 'cloud_controller_db',
      properties: {
        'ccdb' => ccdb_config
      }
    )
  end

  describe 'bpm.yml' do
    let(:template) { job.template('config/bpm.yml') }
    subject(:rendering) do
      rendered_template = YAML.safe_load(template.render({}, consumes: [ccdb_link]))
      get_process_from_bpm(rendered_template, job_name)
    end

    context 'db_scheme is postgres' do
      it { is_expected.to include('executable' => '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-psql') }
    end

    context 'db_scheme is mysql' do
      let(:ccdb_config) { { 'db_scheme' => 'mysql' } }
      it { is_expected.to include('executable' => '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-mysql') }
    end

    context 'db_scheme is not postgres or mysql' do
      let(:ccdb_config) { { 'db_scheme' => 'foo' } }

      it 'raises an error' do
        expect { rendering }.to raise_error('ccdb.db_scheme foo is not supported')
      end
    end

    it { is_expected.to include('args' => ['/var/vcap/jobs/cloud-controller/config/cloud-controller.yml']) }
  end

  describe 'cloud-controller.yml' do
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
end

def get_process_from_bpm(bpm_config, job_name)
  bpm_config['processes'].select { |p| p['name'] == job_name }.first
end
