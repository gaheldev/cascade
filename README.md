# Cascade

## Use OSC with bitwig

### Set up
Create a virtual midi port and connect the OSC controller:
```
sudo modprobe snd_virmidi midi_devs=1
```

### OSC mapping
OSC mapping in Bitwig translates to midi. So there's 8 parameters per page.
To send parameter `n` first select the page `n/8` with:
```
/project/page/selected
```

and then set an integer value from `0` to `128` to the parameter `n%8` with:
```
/project/param/<n%8>/value
```
