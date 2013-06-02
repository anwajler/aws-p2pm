# Copyright 2011-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require File.expand_path(File.dirname(__FILE__) + '/../samples_config')

require 'net/http'
gem 'net-ssh', '~> 2.1.4'
require 'net/ssh'

instance = key_pair = group = nil

begin
  ec2 = AWS::EC2.new
  #puts "  " + ec2.regions.map(&:name).join("\n  ")
  ec2 = ec2.regions["us-west-2"]
  # optionally switch to a non-default region

  images = ec2.images
  puts images.inspect
  image = images["ami-c55fc9f5"]
  puts image.inspect
  puts "Using AMI: #{image.inspect}"

  # generate a key pair
  key_pair = ec2.key_pairs.create("ruby-sample-#{Time.now.to_i}-#{rand(1000000)}")
  puts "Generated keypair #{key_pair.name}, fingerprint: #{key_pair.fingerprint}"

  # open SSH access
  group = ec2.security_groups.create("ruby-sample-#{Time.now.to_i}-#{rand(1000000)}")
  group.authorize_ingress(:tcp, 22, "0.0.0.0/0")
  puts "Using security group: #{group.name}"

  # launch the instance
  instance = image.run_instance(:key_pair => key_pair,
                                :security_groups => group)
  sleep 10 while instance.status == :pending
  puts "Launched instance #{instance.id}, status: #{instance.status}"

  #exit 1 unless instance.status == :running

  begin
    puts "Trying ssh #{instance.ip_address}"
    Net::SSH.start(instance.ip_address, "ubuntu",
                   :key_data => [key_pair.private_key]) do |ssh|
      puts "Running bootstrap"
      puts ssh.exec!("/home/ubuntu/p2p-v1/p2pm/run_p2pp.sh -m 4 -tcp 7080 -p SuperPeer -h SHA-1 -o oid -hl 20 -hb 2 -sra 54.214.254.200 -srp 7080")
    end
  rescue SystemCallError, Timeout::Error => e
    # port 22 might not be available immediately after the instance finishes launching
    sleep 1
    puts "waiting"
    retry
  end

ensure
  # clean up
  #[instance,
  # group,
  # key_pair].compact.each(&:delete)
end
