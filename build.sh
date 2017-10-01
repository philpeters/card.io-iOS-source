#!/bin/sh
rm -Rf ../card.io-iOS-release/*
fab build:outdir=../card.io-iOS-release
mv ../card.io-iOS-release/card.io_ios_*/* ../card.io-iOS-release
rmdir ../card.io-iOS-release/card.io_ios_*
