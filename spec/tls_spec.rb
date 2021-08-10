# frozen_string_literal: true

require_relative 'spec_helper'

describe 'tls files' do
  let(:job_name) { 'cloud-controller' }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:job) { release.job(job_name) }

  describe 'uaa' do
    context 'ca.crt' do
      let(:template) { job.template('tls/uaa/ca.crt') }
      let(:ca_cert) do
        <<~EOCERT
          --- BEGIN CERT ---
          cert contentx
          --- END CERT ---
        EOCERT
      end
      subject { template.render({ 'uaa' => { 'ca_cert' => ca_cert } }, consumes: [DEFAULT_CCDB_LINK]) }

      it { is_expected.to include(ca_cert) }
    end
  end
end
