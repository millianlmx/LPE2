all: helloworld_pi

helloworld_pc : hello.c 
	gcc -L$(TARGET_PC)/lib hello.c -o helloworld_pc -lncurses
	
	
helloworld_pi : hello.c 
	$(CCC) -I$(TARGET_PI)/usr/include/ncurses -I$(TARGET_PI)/usr/include -L$(TARGET_PI)/usr/lib hello.c -o helloworld_pi -lncurses
