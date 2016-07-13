require 'puppet_x/puppetlabs/splunk/type'

Puppet::Type.newtype(:splunk_output) do
  @doc = "Manage splunk output settings in outputs.conf"
  PuppetX::Puppetlabs::Splunk::Type.clone(self)
end
