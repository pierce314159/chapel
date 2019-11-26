use Time;
use Memory;
use CommDiagnostics;

use BlockDist;
use CyclicDist;
use BlockCycDist;
use StencilDist;


type elemType = int;


enum diagMode { performance, correctness, commCount, verboseComm, verboseMem };
enum arraySize { tiny, small, large };
enum distType { block, cyclic, blockCyc, stencil };

config const size = arraySize.tiny;
config const dist = distType.block;
config const mode = diagMode.performance;

// assume homogeneity
const totMem = here.physicalMemory(unit = MemUnits.Bytes);
config const memFraction = 4;

config const createArrays = true;

config const reportInit = true;
config const reportDeinit = true;

config const nElemsTiny = numLocales;
config const nElemsSmall = if mode==diagMode.correctness then 100 else 1000000;
config const nElemsLarge = numLocales*((totMem/numBytes(elemType))/memFraction);

const nElems = if size == arraySize.tiny then nElemsTiny else
               if size == arraySize.small then nElemsSmall else
               if size == arraySize.large then nElemsLarge else -1;


var t = new Timer();

inline proc shouldRunDiag(name) {
  if !reportInit && name.endsWith("Init") then
    return false;
  if !reportDeinit && name.endsWith("Deinit") then
    return false;

  return true;
}

inline proc startDiag(name) {
  if !shouldRunDiag(name) then return;

  select(mode) {
    when diagMode.performance {
      t.start();
    }
    when diagMode.correctness { }
    when diagMode.commCount {
      startCommDiagnostics();
    }
    when diagMode.verboseComm {
      startVerboseComm();
    }
    when diagMode.verboseMem {
      startVerboseMem();
    }
    otherwise {
      halt("Unrecognized diagMode");
    }
  }
}

inline proc endDiag(name) {
  if !shouldRunDiag(name) then return;

  select(mode) {
    when diagMode.performance {
      t.stop();
      writeln(name, ": ", t.elapsed());
      t.clear();
    }
    when diagMode.correctness { }
    when diagMode.commCount {
      stopCommDiagnostics();
      const d = getCommDiagnostics();
      writeln(name, "-GETS: ", + reduce (d.get + d.get_nb));
      writeln(name, "-PUTS: ", + reduce (d.put + d.put_nb));
      writeln(name, "-ONS: ", + reduce (d.execute_on + d.execute_on_fast +
                                        d.execute_on_nb));
      resetCommDiagnostics();
    }
    when diagMode.verboseComm {
      stopVerboseComm();
    }
    when diagMode.verboseMem {
      stopVerboseMem();
    }
    otherwise {
      halt("Unrecognized diagMode");
    }
  }
}

inline proc endDiag(name, x) {
  if mode == diagMode.correctness {
    if x.size != nElems {
      halt(name , " has unexpected size");
    }
  }
  endDiag(name);
}

const localDom = {1..nElems};

if mode == diagMode.correctness || dist == distType.block {
  { // weird blocks are necessary to measure deinit performance
    startDiag("domInit");
    const blockDom = localDom dmapped Block(boundingBox=localDom);
    endDiag("domInit", blockDom);
    if createArrays {
      {
        startDiag("arrInit");
        const blockArr: [blockDom] elemType;
        endDiag("arrInit", blockArr);

        startDiag("arrDeinit");
      }
      endDiag("arrDeinit");
    }
    startDiag("domDeinit");
  }
  endDiag("domDeinit");
}

if mode == diagMode.correctness || dist == distType.cyclic {
  { // weird blocks are necessary to measure deinit performance
    startDiag("domInit");
    const cyclicDom = localDom dmapped Cyclic(startIdx=localDom.first);
    endDiag("domInit", cyclicDom);
    if createArrays {
      {
        startDiag("arrInit");
        const cyclicArr: [cyclicDom] elemType;
        endDiag("arrInit", cyclicArr);

        startDiag("arrDeinit");
      }
      endDiag("arrDeinit");
    }
    startDiag("domDeinit");
  }
  endDiag("domDeinit");
}

if mode == diagMode.correctness || dist == distType.blockCyc {
  { // weird blocks are necessary to measure deinit performance
    startDiag("domInit");
    const blockCyclicDom = localDom dmapped BlockCyclic(startIdx=localDom.first,
                                                        blocksize=5);
    endDiag("domInit", blockCyclicDom);
    if createArrays {
      {
        startDiag("arrInit");
        const blockCyclicArr: [blockCyclicDom] elemType;
        endDiag("arrInit", blockCyclicArr);
        
        startDiag("arrDeinit");
      }
      endDiag("arrDeinit");
    }

    startDiag("domDeinit");
  }
  endDiag("domDeinit");
}

if mode == diagMode.correctness || dist == distType.stencil {
  { // weird blocks are necessary to measure deinit performance
    startDiag("domInit");
    const blockDom = localDom dmapped Stencil(boundingBox=localDom,
                                              fluff=(1,));
    endDiag("domInit", blockDom);
    if createArrays {
      {
        startDiag("arrInit");
        const blockArr: [blockDom] elemType;
        endDiag("arrInit", blockArr);

        startDiag("arrDeinit");
      }
      endDiag("arrDeinit");
    }
    startDiag("domDeinit");
  }
  endDiag("domDeinit");
}