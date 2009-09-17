//
// A helper module for the RA benchmark that defines the random stream
// of values
//
module RARandomStream {
  param randWidth = 64;              // the bit-width of the random numbers
  type randType = uint(randWidth);   // the type of the random numbers

  //
  // bitDom is a non-distributed domain whose indices correspond to
  // the bit positions in the random values.  m2 is a table of helper
  // values used to fast-forward through the random stream.
  //
  pragma "private" const m2: randWidth*randType;
  coforall loc in Locales do on loc do
    computeM2Vals();

  //
  // A serial iterator for the random stream that resets the stream
  // to its 0th element and yields values endlessly.
  //
  def RAStream() {
    var val = getNthRandom(0);
    while (1) {
      getNextRandom(val);
      yield val;
    }
  }

  //
  // A "follower" iterator for the random stream that takes a range of
  // 0-based indices (follower) and yields the pseudo-random values
  // corresponding to those indices.  Follower iterators like these
  // are required for parallel zippered iteration.
  //
  def RAStream(param tag: iterator, follower) where tag == iterator.follower {
    if follower.size != 1 then
      halt("RAStream cannot use multi-dimensional iterator");
    var val = getNthRandom(follower(1).low);
    for follower {
      getNextRandom(val);
      yield val;
    }
  }

  //
  // A helper function for "fast-forwarding" the random stream to
  // position n in O(log2(n)) time
  //
  def getNthRandom(in n: uint(64)) {
    param period = 0x7fffffffffffffff/7;

    n %= period;
    if (n == 0) then return 0x1;
    var ran: randType = 0x2;
    for i in 0..log2(n)-1 by -1 {
      var val: randType = 0;
      for j in 1..randWidth do
        if ((ran >> (j-1)) & 1) then val ^= m2(j);
      ran = val;
      if ((n >> i) & 1) then getNextRandom(ran);
    }
    return ran;
  }

  //
  // A helper function for advancing a value from the random stream,
  // x, to the next value
  //
  def getNextRandom(inout x) {
    param POLY = 0x7;
    param hiRandBit = 0x1:randType << (randWidth-1);

    x = (x << 1) ^ (if (x & hiRandBit) then POLY else 0);
  }

  //
  // A helper function for computing the values of the helper array,
  // m2
  //
  def computeM2Vals() {
    var nextVal = 0x1: randType;
    for param i in 1..randWidth {
      m2(i) = nextVal;
      getNextRandom(nextVal);
      getNextRandom(nextVal);
    }
  }
}
