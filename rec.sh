#!/bin/bash

arecord -D hw -c2 -r 48000 -f S16_LE -t wav -V stereo -v recording.wav

