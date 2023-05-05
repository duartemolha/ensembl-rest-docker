use strict;
use warnings;
use EnsEMBL::REST;
use Plack::Builder;
use Plack::Util;

my $app = EnsEMBL::REST->apply_default_middlewares(EnsEMBL::REST->psgi_app);

builder {
  enable 'DetectExtension';
  enable 'EnsemblRestHeaders';
  enable 'EnsThrottle::Second',
    max_requests => {{MAX_REQUESTS_PER_SECOND}},
    path => sub { 1 },
    backend => Plack::Middleware::EnsThrottle::SimpleBackend->new(),
    message => '{{MAX_REQUESTS_PER_SECOND}}rps Rate exceeded ', 
  $app;
}