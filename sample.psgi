use utf8;
use strict;
use warnings;

use Encode;
use File::Basename qw(dirname);
use Plack::Middleware::Session;
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Session;
use Router::Boom;
use Text::Xslate;
use WebService::Dropbox;

use Data::Printer;

my $tx = Text::Xslate->new({
    syntax => 'TTerse',
});

my $config_file = dirname(__FILE__) . '/config.pl';
my $config = do $config_file;

my $dropbox = WebService::Dropbox->new({
    key    => $config->{dropbox}->{app_key},
    secret => $config->{dropbox}->{app_secret},
});

my $router = Router::Boom->new;
$router->add('/', sub {
    my ($req, $session) = @_;
    my $vars = +{
        title => 'dropbox api sample',
        data  => $session->remove('data'),
    };
    my $html = Encode::encode(Encode::find_encoding('utf-8'), $tx->render('index.tt', $vars));
    return ['200', ['Content-Type' => 'text/html', 'Content-length' => length($html)], [$html]];
});

$router->add('/login', sub {
    my ($req, $session) = @_;
    my $uri = $dropbox->authorize({ redirect_uri => $config->{dropbox}->{redirect_uri} });
    my $res = Plack::Response->new(301);
    $res->redirect($uri);
    return $res->finalize;
});

$router->add('/auth', sub {
    my ($req, $session) = @_;
    my $code = $req->param('code');
    my $token = $dropbox->token($code, $config->{dropbox}->{redirect_uri});
    my $account = $dropbox->get_current_account || { error => $dropbox->error };
    $session->set('data', $account);

    my $res = Plack::Response->new(301);
    $res->redirect('./');
    return $res->finalize;
});

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $session = Plack::Session->new($env);
    my ($code) = $router->match($env->{PATH_INFO});
    return ['404', ['Content-Type' => 'text/plain'], ['Not Found.']] unless $code;
    return $code->($req, $session);
};

builder {
    enable "Session";
    $app;
}

__END__
