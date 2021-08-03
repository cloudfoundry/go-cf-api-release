require 'rspec'
require 'bosh/template/test'
require 'bosh/template'

describe 'cloud-controller' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  let(:ccdb_link) do
    Bosh::Template::Test::Link.new(
      name: 'cloud_controller_db',
      properties: {
        'ccdb' => ccdb_config
      }
    )
  end
  let(:rendered_template) do
    template.render({}, consumes: [ccdb_link])
  end

  describe 'bpm.yml' do
    let(:template) { job.template('config/bpm.yml') }
    let(:ccdb_config) { {'db_scheme' => 'postgres'} }

    context 'postgres' do
      it 'uses the psql binary when ccdb.db_scheme is postgres' do
        process = get_process_from_bpm(YAML.safe_load(rendered_template), job_name)
        expect(process['executable']).to eq '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-psql'
      end
    end

    context 'mysql' do
      let(:ccdb_config) { {'db_scheme' => 'mysql'} }

      it 'uses the mysql binary when ccdb.db_scheme is mysql' do
        process = get_process_from_bpm(YAML.safe_load(rendered_template), job_name)
        expect(process['executable']).to eq '/var/vcap/jobs/cloud-controller/packages/cloud-controller/cloud-controller-mysql'
      end
    end

    context 'db_scheme is not postgres or mysql' do
      let(:ccdb_config) { {'db_scheme' => 'foo'} }

      it 'raises an error' do
        expect { rendered_template }.to raise_error('ccdb.db_scheme foo is not supported')
      end
    end

    it 'passes the config file path to the binary' do
      process = get_process_from_bpm(YAML.safe_load(rendered_template), job_name)
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

    context 'postgres' do
      let(:ccdb_config) { default_ccdb_config }

      it 'creates a psql connection string' do
        config_file = YAML.safe_load(rendered_template)
        expect(config_file['db']['connectionstring']).to eq 'host=db.example.com port=1234 user=admin_user dbname=ccdb password=admin_password sslmode=disable'
      end
    end

    context 'mysql' do
      let(:ccdb_config) { default_ccdb_config.merge({ 'db_scheme' => 'mysql' }) }

      it 'creates a mysql connection string' do
        config_file = YAML.safe_load(rendered_template)
        expect(config_file['db']['connectionstring']).to eq 'admin_user:admin_password@tcp(db.example.com:1234)/ccdb?tls=false&parseTime=true'
      end
    end

    context 'missing address property' do
      let(:ccdb_config) { default_ccdb_config.reject { |k, _| k == 'address' } }

      it 'raises an error' do
        expect { rendered_template }.to raise_error(KeyError, 'key not found: "address"')
      end
    end

    context 'missing port property' do
      let(:ccdb_config) { default_ccdb_config.reject { |k, _| k == 'port' } }

      it 'raises an error' do
        expect { rendered_template }.to raise_error(KeyError, 'key not found: "port"')
      end
    end
  end
end

def get_process_from_bpm(bpm_config, job_name)
  bpm_config['processes'].select { |p| p['name'] == job_name }.first
end
