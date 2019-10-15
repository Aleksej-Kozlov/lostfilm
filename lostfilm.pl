#!/usr/bin/perl

# Download new torrents from lostfilm.tv
# by Aleksej Kozlov <ovoled@gmail.com> 2019

use strict;
use warnings;
use utf8;
use Encode;
use Scalar::Util qw(looks_like_number);
use URI;
use LWP::Simple;
use LWP::Protocol::http;
use HTML::TreeBuilder 5 -weak;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $download_dir = 'torrents';

check_env('LOSTFILM_COOKIE');

work();


sub work {
    my $uri_news = 'http://www.lostfilm.tv/new/';
    my $uri_search = 'http://www.lostfilm.tv/v_search.php?a=';

    my $ua = prepare_ua();
    my $tree_news = fetch_page($ua, $uri_news, undef);
    my @arr_episode = $tree_news->look_down('_tag' => 'div', 'class' => 'row') or die "<$uri_news>\ncontent error";
    foreach my $item_episode (@arr_episode) {
        my $a_episode = $item_episode->look_down('_tag' => 'a') or die "<$uri_news>\ncontent error";
        my $href_episode = $a_episode->attr('href') or die "<$uri_news>\ncontent error";
        my $uri_episode = URI->new_abs($href_episode, $uri_news);
        my $tree_episode = fetch_page($ua, $uri_episode, undef);

        my $download_button = $tree_episode->look_down('_tag' => 'div', 'class' => 'external-btn') or die "<$uri_episode>\ncontent error";
        my $id_episode = $download_button->attr('onclick') or die "<$uri_episode>\ncontent error";
        $id_episode =~ s/^PlayEpisode\('(.*)'\)$/$1/;
        looks_like_number($id_episode) or die "<$uri_episode>\ncontent error";
        my $tree_search = fetch_page($ua, $uri_search . $id_episode, $ENV{'LOSTFILM_COOKIE'});

        my $a_retre = $tree_search->look_down('_tag' => 'a') or die "<$uri_episode>\ncontent error";
        my $uri_retre = $a_retre->attr('href') or die "<$uri_episode>\ncontent error";
        my $tree_retre = fetch_page($ua, $uri_retre, undef);

        my $episode_title1 = $tree_retre->look_down('_tag' => 'div', 'class' => 'inner-box--title') or die "<$uri_retre>\ncontent error";
        $episode_title1 = $episode_title1->as_text or die "<$uri_retre>\ncontent error";
        $episode_title1 = trim($episode_title1);
        print "$episode_title1\n";

        my $episode_title2 = $tree_retre->look_down('_tag' => 'div', 'class' => 'inner-box--text') or die "<$uri_retre>\ncontent error";
        $episode_title2 = $episode_title2->as_text or die "<$uri_retre>\ncontent error";
        $episode_title2 = trim($episode_title2);
        print "$episode_title2\n";

        my @arr_video = $tree_retre->look_down('_tag' => 'div', 'class' => 'inner-box--link main') or die "<$uri_retre>\ncontent error";
        foreach my $item_video (@arr_video) {
            my $a_video = $item_video->look_down('_tag' => 'a');
            my $uri_video = $a_video->attr('href');
            #print "<$uri_video>\n";
            fetch_file($ua, $uri_video);
        }
        print "\n";
    }
}


sub fetch_page {
    my ($ua, $uri, $cookie) = @_;

    my $req = HTTP::Request->new(GET => $uri, HTTP::Headers->new(defined $cookie ? ('Cookie' => $cookie) : ()));
    my $rsp = $ua->request($req);
    $rsp->is_success or die "<$uri>\nerror fetching page [" . $rsp->status_line. "]\n";
    my $content = $rsp->as_string;
    $content = decode('utf-8', $content);

    my $tree = HTML::TreeBuilder->new_from_content($content) or die "<$uri>\nerror parsing page [$!]\n";
    return $tree;
}


sub fetch_file {
    my ($ua, $uri) = @_;

    my $req = HTTP::Request->new(GET => $uri);
    my $rsp = $ua->request($req);
    $rsp->is_success or die "<$uri>\nerror fetching file [" . $rsp->status_line. "]\n";
    my $content = $rsp->content or die "<$uri>\nerror fetching file\n";
    my $condisp = $rsp->header('Content-Disposition') or die "<$uri>\nno Content-Disposition header\n";
    $condisp =~ /^attachment;filename="([^"]*)"$/ or die "<$uri>\nunexpected Content-Disposition header [$condisp]\n";
    my $filename = $1;
    print "$filename\n";

    mkdir $download_dir if (!-e $download_dir);
    $filename = "$download_dir/$filename";
    die "file already exists\n" if (-e $filename);
    open my $fh, '>', $filename or die "error creating file [$!]\n";
    binmode $fh or die "error writing to file [$!]\n";
    print $fh $content or die "error writing to file [$!]\n";
    close $fh or die "error writing to file [$!]\n";
}


sub prepare_ua {
    my $ua = LWP::UserAgent->new(protocols_allowed => ['http'], keep_alive => 1);
    #$ua->show_progress(1);
    if (defined $ENV{'URL_PROXY'}) {
        $ua->proxy(['http'], $ENV{'URL_PROXY'});
    }
    if (defined $ENV{'HTTP_USERAGENT'}) {
        $ua->agent($ENV{'HTTP_USERAGENT'});
    }
    return $ua;
}


sub trim {
    my ($s) = @_;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}


sub check_env {
    my ($name) = @_;
    defined $ENV{$name} or die "env var $name must be set\n";
}
