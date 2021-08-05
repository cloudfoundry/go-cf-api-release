# frozen_string_literal: true

require_relative 'spec_helper'

describe 'route-registrar-health-check.sh' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }
  let(:template) { job.template('bin/route-registrar-health-check.sh') }
  let(:config) { {} }

  subject { template.render(config, consumes: [DEFAULT_CCDB_LINK]) }

  it {
    is_expected.to include(
      '#!/usr/bin/env bash',
      'curl --insecure --fail https://localhost:443/healthz'
    )
  }

  context 'custom tls port' do
    let(:config) { { 'cc' => { 'public_tls' => { 'port' => 1234 } } } }
    it {
      is_expected.to include(
        '#!/usr/bin/env bash',
        'curl --insecure --fail https://localhost:1234/healthz'
      )
    }
  end
end
