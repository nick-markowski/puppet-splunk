require 'puppet_x/puppetlabs/splunk/type'

Puppet::Type.newtype(:splunk_transforms) do
  @doc = "Manage splunk transforms settings in transforms.conf"
  PuppetX::Puppetlabs::Splunk::Type.clone(self)
end
