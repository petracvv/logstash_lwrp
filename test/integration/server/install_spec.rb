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