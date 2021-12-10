# frozen_string_literal: true

require_relative 'spec_helper'

describe 'bpm.yml' do
  let(:job_name) { 'go-cf-api' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  let(:template) { job.template('config/bpm.yml') }
  let(:ccdb_config) { { 'db_scheme' => 'postgres' } }
  let(:ccdb_link) do
    Bosh::Template::Test::Link.new(
      name: 'cloud_controller_db',
      properties: {
        'ccdb' => ccdb_config
      }
    )
  end
  subject(:rendering) do
    rendered_template = YAML.safe_load(template.render({}, consumes: [ccdb_link]))
    get_process_from_bpm(rendered_template, job_name)
  end

  context 'db_scheme is postgres' do
    it { is_expected.to include('executable' => '/var/vcap/jobs/go-cf-api/packages/go-cf-api/go-cf-api-psql') }
  end

  context 'db_scheme is mysql' do
    let(:ccdb_config) { { 'db_scheme' => 'mysql' } }
    it { is_expected.to include('executable' => '/var/vcap/jobs/go-cf-api/packages/go-cf-api/go-cf-api-mysql') }
  end

  context 'db_scheme is not postgres or mysql' do
    let(:ccdb_config) { { 'db_scheme' => 'foo' } }

    it 'raises an error' do
      expect { rendering }.to raise_error('ccdb.db_scheme foo is not supported')
    end
  end

  it { is_expected.to include('args' => ['/var/vcap/jobs/go-cf-api/config/go-cf-api.yml']) }
end

def get_process_from_bpm(bpm_config, job_name)
  bpm_config['processes'].select { |p| p['name'] == job_name }.first
end
