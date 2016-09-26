#!/bin/sh
fab build:outdir=../card.io-iOS-release
mv ../card.io-iOS-release/card.io-iOS-* ../ 
