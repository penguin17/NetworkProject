#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *


class TestSim:
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_LINK_DUMP=2
    CMD_ROUTE_DUMP=3
    TEST_CLIENT = 4
    TEST_SERVER = 5
    CMD_KILL = 6;

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2];
                self.r.add(int(s[0]), int(s[1]), float(s[2]))

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in range(1, self.numMote+1):
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in range(1, self.numMote+1):
            print "Creating noise model for ",i;
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in range(1, self.numMote+1):
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        self.msg.set_dest(dest);
        self.msg.set_id(ID);
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def neighborDMP(self, source,destination,msg):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, source, "{0}{1}".format(chr(destination),msg));

    def routeDMP(self, destination):
        self.sendCMD(2, destination, "routing command");

    def mapDMP(self,destination):
        self.sendCMD(3,destination,"map command");

    def addChannel(self, channelName, out=sys.stdout):
        print 'Adding Channel', channelName;
        self.t.addChannel(channelName, out);

    def cmdTestServer(self,source,port):
        self.sendCMD(self.TEST_SERVER,source,"{0}".format(chr(port)));

    def cmdTestClient(self,source,dest,srcPort,destPort,transfer):
        self.sendCMD(self.TEST_CLIENT,source,"{0}{1}{2}{3}".format(chr(dest),chr(srcPort),chr(destPort),chr(transfer)));
    def cmdCloseClient(self,source,dest,srcPort,destPort):
        self.sendCMD(self.CMD_KILL,source,"{0}{1}{2}".format(chr(dest),chr(srcPort),chr(destPort)));

def main():
    s = TestSim();
    s.runTime(200);
    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);

    s.runTime(20);

    
    # s.runTime(200);
    # s.ping(1, 2, "Hello, World");
    # s.runTime(20);
    # s.ping(1,3,"wowzers!");
    # s.runTime(20);
    # s.ping(1,19,"Finally did it!!!");
    # s.runTime(30);
    
    print("Testing Testserver");
    s.cmdTestServer(5,20);
    s.runTime(100);

    print("Testing TestClient");
    s.cmdTestClient(1,5,20,20,20);
    s.runTime(100);

    # print("Testing ClosingClient");
    # s.cmdCloseClient(1,5,20,20);
    # s.runTime(40);


	

if __name__ == '__main__':
    main()
