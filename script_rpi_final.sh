#! /bin/sh

workingDir=$(pwd)
export PATH_CC=$workingDir/src_rpi/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin
export CCC=$PATH_CC/arm-linux-gnueabihf-gcc
export CXX=$PATH_CC/arm-linux-gnueabihf-g++
export CC=$CCC
export TARGET_PI=/mnt/rpi-root
export TARGET_PI_cfiles=mnt/rpi-root
export PREFIX=/local

cd src_rpi/
if [ ! -e $workingDir/src_rpi/tools-master/ ]; then
    unzip tools-master.zip
fi

# Création des partitions
echo "Création des partitions"
echo "o

n
p
1

+100M

t
c
a

n
p


+200M
w" | sudo fdisk /dev/mmcblk0

# create /mnt/rpi-boot and /mnt/rpi-root if not exists
mkdir -p /mnt/rpi-boot
mkdir -p $TARGET_PI

# Créer système de fichiers
echo "Créer système de fichiers"
/sbin/mkfs.vfat -n BOOT /dev/mmcblk0p1
/sbin/mkfs.ext4 -L ROOT /dev/mmcblk0p2

# Copie des fichiers de boot depuis /home/millian/LA1/linux_pour_embarque/src_rpi/boot_rpi/
echo "Copie des fichiers de boot"
mount /dev/mmcblk0p1 /mnt/rpi-boot
cd $workingDir/src_rpi/
cp -r $workingDir/src_rpi/boot_rpi/* /mnt/rpi-boot

sleep 5

# Instalation de busybox sur $TARGET_PI
echo "Instalation de busybox"
mount /dev/mmcblk0p2 $TARGET_PI

cd $workingDir/src_rpi

if [ ! -e $workingDir/src_rpi/busybox/ ]; then
    git clone https://github.com/mirror/busybox.git busybox
fi
cd $workingDir/src_rpi/busybox/
make clean
cp $workingDir/src_rpi/.config $workingDir/src_rpi/busybox/.config
make -j$(nproc) ARCH=arm CROSS_COMPILE=$PATH_CC/arm-linux-gnueabihf-
make install CONFIG_PREFIX=$TARGET_PI ARCH=arm CROSS_COMPILE=$PATH_CC/arm-linux-gnueabihf-

# Copie de lib pour busybox
mkdir -p $TARGET_PI/lib
cp -r $workingDir/src_rpi/tools-master/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/arm-linux-gnueabihf/libc/lib/arm-linux-gnueabihf/* $TARGET_PI/lib

mkdir -p $TARGET_PI/usr/share/udhcpc
cd $workingDir/src_rpi/busybox/examples/udhcp/
cp simple.script $TARGET_PI/usr/share/udhcpc/default.script
chmod +x $TARGET_PI/usr/share/udhcpc/default.script

rm -rf $workingDir/src_rpi/busybox/

sleep 5

# Création des répertoires /dev /proc /sys /etc
mkdir -p $TARGET_PI/dev
mkdir -p $TARGET_PI/proc
mkdir -p $TARGET_PI/sys
mkdir -p $TARGET_PI/etc

# Ajout de profile global pour définir des variables d'environnement
cat << EOF >> $TARGET_PI/etc/profile
export TERMINFO=/usr/share/terminfo/
EOF

cd $TARGET_PI/dev 
/sbin/MAKEDEV generic console
chmod -R 777 $TARGET_PI/dev

mkdir -p $TARGET_PI/etc/init.d/

# Ajout de inittab
cat << EOF >> $TARGET_PI/etc/inittab
::sysinit:/etc/init.d/rcS
tty1::respawn:/bin/login
tty2::respawn:/bin/login
tty3::respawn:/bin/login
tty4::respawn:/bin/login
ttyAMA0::respawn:/bin/login
EOF

touch $TARGET_PI/etc/fstab

# Ajout du clavier français
cd $workingDir/src_rpi/
cp azerty.kmap $TARGET_PI/etc/french.kmap

# Ajout du script rcS
cat << EOF >> $TARGET_PI/etc/init.d/rcS
#! /bin/sh
mkdir /dev/pts
mount -t devpts devpts /dev/pts
mount -t proc proc /proc
mount -o remount,rw /
mount -a
loadkmap < /etc/french.kmap
chmod 777 /dev/fb0

udhcpc -i eth0 --background /etc/share/udhcpc/default.script

httpd -h /var/www
EOF
chmod +x $TARGET_PI/etc/init.d/rcS

# gestion des utilisateurs avec mot de passe par defaut abc123
mkdir -p $TARGET_PI/home/millian
mkdir -p $TARGET_PI/root
password=$(openssl passwd -1 -salt xyz abc123)
echo "root:x:0:0:root:/root:/bin/ash" >> $TARGET_PI/etc/passwd
echo "root:$password:18657:0:99999:7:::" >> $TARGET_PI/etc/shadow
echo "millian:x:1003:100:users:/home/millian:/bin/ash" >> $TARGET_PI/etc/passwd
echo "millian:$password:18657:0:99999:7:::" >> $TARGET_PI/etc/shadow

# gestion des groupes
echo "root:x:0:" >> $TARGET_PI/etc/group
echo "users:x:100:" >> $TARGET_PI/etc/group
echo "video:x:1000:millian" >> $TARGET_PI/etc/group

# gestion des profiles pour définir des variables d'environnement
cat << EOF >> $TARGET_PI/root/.profile
export TERMINFO=/usr/share/terminfo/
EOF
cat << EOF >> $TARGET_PI/home/millian/.profile
export TERMINFO=/usr/share/terminfo/
EOF

# Téléchargement des sources de ncurses et compilation
cd $workingDir/src_rpi/
if [ ! -e $workingDir/src_rpi/ncurses/ ]; then
    git clone https://github.com/mirror/ncurses.git ncurses
fi
cd $workingDir/src_rpi/ncurses/
make clean
./configure --with-shared --disable-stripping --prefix=$TARGET_PI/usr --host=x86_64-build_unknown-linux-gnu --target=arm-linux-gnueabihf
make -j$(nproc)
make install
rm -rf $workingDir/src_rpi/ncurses/

# Compilation d'un gestionnaire de fichier en Ncurses
cd $workingDir/src_rpi/
if [ ! -e $workingDir/src_rpi/cfiles/ ]; then
    git clone https://github.com/mananapr/cfiles.git cfiles
fi
cp $workingDir/src_rpi/Makefile.cfiles $workingDir/src_rpi/cfiles/Makefile
cd cfiles/
make 
make install
rm -rf $workingDir/src_rpi/cfiles/

# installation d'un executable ncurses d'exemple
cd $workingDir/src_rpi/
make helloworld_pi
cp helloworld_pi $TARGET_PI/usr/bin/

# installation de wiring pi
echo "Installing WiringPi..."

# Download WiringPi
cd $workingDir/src_rpi/
if [ ! -d wiringPi ]; then
    # Extract WiringPi
    tar -xvf wiringPi.tar.gz
    mv wiringPi-36fb7f1 wiringPi
fi

# Install WiringPi
cd $workingDir/src_rpi/wiringPi/wiringPi/
make clean
export DESTDIR=$TARGET_PI
export PREFIX=""
export CC=$CCC
make V=1 -j$(nproc)
make install

# Install WiringPiDev
cd ../devLib
make clean
export DESTDIR=$TARGET_PI
export PREFIX=""
export CC="$CCC -I$DESTDIR/include"
make V=1 -j$(nproc)
make install

# Install GPIO
cd ../gpio
make clean
export DESTDIR="$TARGET_PI"
export PREFIX=""
export CC="$CCC"
make V=1 -j$(nproc)
make install
rm -rf $workingDir/src_rpi/wiringPi/

# correction des liens symboliques
cd $TARGET_PI/lib/
rm libwiringPi.so
ln -s libwiringPi.so.2.50 libwiringPi.so
rm libwiringPiDev.so
ln -s libwiringPiDev.so.2.50 libwiringPiDev.so

cd $workingDir

export CFLAGS="-I$TARGET_PI/include"
export LDFLAGS="-L$TARGET_PI/lib"


# FBV
## libjpeg
cd $workingDir/src_rpi/
tar -xvf jpegsrc.v9e.tar.gz
cd jpeg-9e/
cp testimg.jpg $TARGET_PI/home/millian/
make clean
./configure --host=x86_64-build_unknown-linux-gnu --target=arm-linux-gnueabihf --prefix=""
make -j$(nproc)
make install
rm -rf $workingDir/src_rpi/jpeg-9e/

sleep 10

## libpng
### libz
cd $workingDir/src_rpi/
tar -xvf zlib-1.2.13.tar.gz
cd zlib-1.2.13/
./configure --prefix=""
make -j$(nproc) LDSHARED="${CCC} -shared -Wl,-soname,libz.so.1,--version-script,zlib.map"
make install
rm -rf $workingDir/src_rpi/zlib-1.2.13/

cd $workingDir/src_rpi/
tar -xvf libpng-1.6.39.tar.gz
cd libpng-1.6.39/
cp pngnow.png $TARGET_PI/home/millian/
./configure --prefix="" --with-zlib-prefix=$TARGET_PI --host=x86_64-build_unknown-linux-gnu --build=arm-linux-gnueabihf
make -j$(nproc) INCLUDES="-I$TARGET_PI/include"
make install INCLUDES="-I$TARGET_PI/include"
rm -rf $workingDir/src_rpi/libpng-1.6.39/

## fbv
cd $workingDir/src_rpi/
unzip fbv-master.zip
cd fbv-master/
./configure --prefix="$TARGET_PI" --without-bmp --libs="-I$TARGET_PI/include/libpng16 -I$TARGET_PI/include -L$TARGET_PI/lib -lpng -lz -ljpeg -lm"
make ARCH=arm CROSS_COMPILE="${CC_PATH}/arm-linux-gnueabihf-" -j$(nproc) CFLAGS="-I$TARGET_PI/include/libpng16 -I$TARGET_PI/include" LDFLAGS="-L$TARGET_PI/lib -lpng -lz -ljpeg -lm"
make ARCH=arm CROSS_COMPILE="${CC_PATH}/arm-linux-gnueabihf-" install
rm -rf $workingDir/src_rpi/fbv-master/

rm -rf $workingDir/src_rpi/tools-master/

mkdir -p $TARGET_PI/var/www/
cp $workingDir/src_rpi/index.html $TARGET_PI/var/www/

umount /mnt/rpi-boot
umount $TARGET_PI