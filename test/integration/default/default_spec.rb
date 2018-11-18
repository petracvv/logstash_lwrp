# # encoding: utf-8

# Inspec test for resource logstash_install

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

# Installation
describe package('tar') do
  it { should be_installed}
end

describe group('logstash') do
  it {should exist}
end

describe user('logstash') do
  it { should exist }
  its('group') { should eq 'logstash'}
  its('shell') { should eq '/sbin/nologin'}
  its('uid') { should be < 1000}
end

describe file('/opt/logstash_kitchen') do
  it {should be_symlink}
end

installdir = file('/opt/logstash_kitchen').link_path

describe directory(installdir) do
  it { should exist }
  it { should be_owned_by 'logstash'}
  it { should be_grouped_into 'logstash'}
end

# Test extraction and chown
describe file("#{installdir}/LICENSE.txt") do
  it { should exist }
  its('owner') { should eq 'logstash'} 
  its('group') { should eq 'logstash'} 
  its('content') { should match /ELASTIC LICENSE AGREEMENT/}
end

# Configuration
describe file('/opt/logstash_kitchen/config/logstash.yml') do
  it {should exist}
  its('owner') { should eq 'logstash'}
  its('group') { should eq 'logstash'}
  its('mode') {should cmp '0640'}
  its('content') {should match /node\.name: logstash-kitchen/}
  its('content') {should match /path\.data: \/opt\/logstash_kitchen\/data/}
  its('content') {should match /path\.logs: \/opt\/logstash_kitchen\/logs/}
  its('content') {should match /log\.level: info/}
  its('content') {should match /log\.format: plain/}
  its('content') {should match /queue\.type: persisted/}
  its('content') {should match /config\.reload\.automatic: true/}
end

# Pipelines
describe file('/opt/logstash_kitchen/config/pipelines.yml') do
  it {should exist}
  its('owner') { should eq 'logstash'}
  its('group') { should eq 'logstash'}
  its('mode') {should cmp '0640'}
  its('content') { should match /pipeline.id: main/}
  its('content') { should match /pipeline.workers: 1/}
  its('content') { should match /path.config: "\/opt\/logstash_kitchen\/pipelines\/main"/}
  its('content') { should match /pipeline.id: testing/}
  its('content') { should match /path.config: "\/opt\/logstash_kitchen\/pipelines\/testing"/}
  its('content') { should match /config.string: input { generator/}
  its('content') { should match /queue.type: memory/}
end

# Service
describe file('/opt/logstash_kitchen/config/jvm.options') do
  it {should exist}
  its('owner') { should eq 'logstash'}
  its('group') { should eq 'logstash'}
  its('mode') {should cmp '0640'}
  its('content') { should match /-Xms256M/}
  its('content') { should match /-Xmx256M/}
  its('content') { should match /-XX:\+UseParNewGC/}
  its('content') { should match /-Djava.awt.headless=true/}
end

describe file('/opt/logstash_kitchen/config/startup.options') do
  it {should exist}
  its('owner') { should eq 'logstash'}
  its('group') { should eq 'logstash'}
  its('mode') {should cmp '0640'}
  its('content') { should match /JAVACMD=\/usr\/bin\/java/}
  its('content') { should match /LS_HOME=\/opt\/logstash_kitchen/}
  its('content') { should match /LS_SETTINGS_DIR=\/opt\/logstash_kitchen\/config/}
  its('content') { should match /LS_OPTS="--path.settings \/opt\/logstash_kitchen\/config"/}
  its('content') { should match /LS_PIDFILE=\/var\/run\/logstash_kitchen.pid/}
  its('content') { should match /LS_USER=logstash/}
  its('content') { should match /LS_GROUP=logstash/}
  its('content') { should match /LS_GC_LOG_FILE=\/opt\/logstash_kitchen\/logs\/logstash_kitchen_gc.log/}
  its('content') { should match /LS_OPEN_FILES=16384/}
  its('content') { should match /LS_NICE=19/}
  its('content') { should match /SERVICE_NAME="logstash_kitchen"/}
  its('content') { should match /SERVICE_DESCRIPTION="logstash"/}
end

# Centos 6 needs upstart specified
if os.release.start_with?('6')
  describe upstart_service('logstash_kitchen') do
    it {should be_enabled}
    it {should be_running}
  end
else
  describe service('logstash_kitchen') do
    it {should be_enabled}
    it {should be_running}
  end
end