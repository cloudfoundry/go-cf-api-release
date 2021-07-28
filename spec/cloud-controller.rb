require 'rspec'
require 'bosh/template/test'

describe 'cloud-controller' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  describe 'bpm.yml' do
    let(:template) { job.template('config/bpm.yml') }

    it 'uses the psql binary when ccdb.db_scheme is postgres' do
      process = get_process_from_bpm(YAML::load(template.render({})), job_name)
      expect(process['executable']).to eq 'cloud-controller-psql'
    end

    it 'uses the mysql binary when ccdb.db_scheme is mysql' do
      config = {'ccdb' => { 'db_scheme' => 'mysql'}}
      process = get_process_from_bpm(YAML::load(template.render(config)), job_name)
      expect(process['executable']).to eq 'cloud-controller-mysql'
    end

    it 'raises an error if ccdb.db_scheme is not postgres or mysql' do
      config = {'ccdb' => { 'db_scheme' => 'foo'}}
      expect{ template.render(config) }.to raise_error('ccdb.db_scheme foo is not supported')
    end

    it 'passes the config file path to the binary' do
      process = get_process_from_bpm(YAML::load(template.render({})), job_name)
      expect(process['args']).to eq ['/var/vcap/jobs/cloud-controller/config/cloud-controller.yml']
    end
  end
end

def get_process_from_bpm(bpm_config, job_name)
  return bpm_config['processes'].select { |p| p['name'] == job_name }.first
end