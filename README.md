# Google Voice Bonnet

I tried and failed to update the old Google driver for the Raspberry Pi voice bonnet to run under Bullseye. Instead, I tried writing some perl code to initialise the bonnet to be able to play and record audio, based on the code in the driver (see init.pl). I failed at that too! Undeterred, I loaded the original Google complete build (ie including the OS) then dumped the contents of every register in the ALC5645 chip. I then wrote some perl code to upload these register contents back into the device (see upload.pl), and this time it worked! At least, it did for recording but not for playing audio.

To record audio, first run "perl upload.pl record" then use the rec.sh script to record.

I also managed to get the LEDs on the pushbutton to work (see leds.pl). The button itself is mapped directly to a GPIO so would be simple to read. 
