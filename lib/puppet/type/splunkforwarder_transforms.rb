require 'puppet_x/puppetlabs/splunk/type'

Puppet::Type.newtype(:splunkforwarder_transforms) do
  @doc = "Manage splunkforwarder transforms settings in transforms.conf"
  PuppetX::Puppetlabs::Splunk::Type.clone(self)
end
