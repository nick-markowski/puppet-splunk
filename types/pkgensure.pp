type Splunk::Pkgensure = Variant[Enum['present','installed','absent','purged','held','latest'],Pattern[/^(\d\.)+\d+-(\d|[a-z]){12}$/]]
