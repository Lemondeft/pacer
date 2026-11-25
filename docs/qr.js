/* Pure ISO/IEC 18004 QR Code encoder (Byte mode, EC level M, versions 1..12).
 * Zero external dependencies. Exposes window.PacerQR in browsers and module.exports in Node.
 */
(function (root) {
  'use strict';

  // Official ISO/IEC 18004 Level M tables for versions 1..12:
  // [totalCodewords, ecCodewordsPerBlock, group1Blocks, group1DataCws, group2Blocks, group2DataCws]
  var VERSION_M = [
    null,
    [26, 10, 1, 16, 0, 0],     // v1  (max 14 bytes)
    [44, 16, 1, 28, 0, 0],     // v2  (max 26 bytes)
    [70, 26, 1, 44, 0, 0],     // v3  (max 42 bytes)
    [100, 18, 2, 32, 0, 0],    // v4  (max 62 bytes)
    [134, 24, 2, 43, 0, 0],    // v5  (max 84 bytes)
    [172, 16, 4, 27, 0, 0],    // v6  (max 106 bytes)
    [196, 18, 4, 31, 0, 0],    // v7  (max 122 bytes)
    [242, 22, 2, 38, 2, 39],   // v8  (max 152 bytes)
    [292, 22, 3, 36, 2, 37],   // v9  (max 180 bytes)
    [346, 26, 4, 43, 1, 44],   // v10 (max 213 bytes)
    [404, 30, 1, 50, 4, 51],   // v11 (max 251 bytes)
    [466, 22, 6, 36, 2, 37],   // v12 (max 287 bytes)
  ];

  // Official ISO/IEC 18004 alignment pattern centers for versions 1..12.
  var ALIGNMENT = [
    null,
    [],
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42],
    [6, 26, 46],
    [6, 28, 50],
    [6, 30, 54],
    [6, 32, 58],
  ];

  // GF(256) with primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11d)
  var GF_EXP = new Uint8Array(512);
  var GF_LOG = new Uint8Array(256);
  (function initGF() {
    var x = 1;
    for (var i = 0; i < 255; i++) {
      GF_EXP[i] = x;
      GF_LOG[x] = i;
      x <<= 1;
      if (x & 0x100) x ^= 0x11d;
    }
    for (var j = 255; j < 512; j++) GF_EXP[j] = GF_EXP[j - 255];
  })();

  function gfMul(a, b) {
    if (a === 0 || b === 0) return 0;
    return GF_EXP[GF_LOG[a] + GF_LOG[b]];
  }

  function rsGenerator(degree) {
    var poly = [1];
    for (var i = 0; i < degree; i++) {
      var next = new Array(poly.length + 1).fill(0);
      var factor = GF_EXP[i];
      for (var j = 0; j < poly.length; j++) {
        next[j] ^= poly[j];
        next[j + 1] ^= gfMul(poly[j], factor);
      }
      poly = next;
    }
    return poly;
  }

  function rsRemainder(data, ecCount) {
    var gen = rsGenerator(ecCount);
    var rem = new Array(ecCount).fill(0);
    for (var i = 0; i < data.length; i++) {
      var factor = data[i] ^ rem[0];
      rem.shift();
      rem.push(0);
      if (factor !== 0) {
        for (var j = 0; j < ecCount; j++) {
          rem[j] ^= gfMul(gen[j + 1], factor);
        }
      }
    }
    return rem;
  }

  function utf8Bytes(str) {
    if (typeof TextEncoder !== 'undefined') {
      return Array.from(new TextEncoder().encode(str));
    }
    var bytes = [];
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      if (c < 0x80) bytes.push(c);
      else if (c < 0x800) bytes.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
      else bytes.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    }
    return bytes;
  }

  function chooseVersion(byteLen) {
    for (var v = 1; v < VERSION_M.length; v++) {
      var spec = VERSION_M[v];
      var dataCws = spec[2] * spec[3] + spec[4] * spec[5];
      var lenBits = v < 10 ? 8 : 16;
      var capacityBytes = Math.floor((dataCws * 8 - 4 - lenBits) / 8);
      if (byteLen <= capacityBytes) return v;
    }
    throw new Error('QR payload exceeds version 12 Level M capacity (' + byteLen + ' bytes)');
  }

  function buildCodewords(bytes, version) {
    var spec = VERSION_M[version];
    var ecPerBlock = spec[1];
    var g1Count = spec[2], g1Data = spec[3];
    var g2Count = spec[4], g2Data = spec[5];
    var totalDataCws = g1Count * g1Data + g2Count * g2Data;

    var bits = [];
    function pushBits(val, count) {
      for (var i = count - 1; i >= 0; i--) bits.push((val >>> i) & 1);
    }

    // Mode indicator: Byte = 0100
    pushBits(0x4, 4);
    pushBits(bytes.length, version < 10 ? 8 : 16);
    for (var i = 0; i < bytes.length; i++) pushBits(bytes[i], 8);

    // Terminator (up to 4 zero bits)
    var maxBits = totalDataCws * 8;
    var term = Math.min(4, maxBits - bits.length);
    pushBits(0, term);

    // Pad to byte boundary
    while (bits.length % 8 !== 0) bits.push(0);

    var dataCws = [];
    for (var b = 0; b < bits.length; b += 8) {
      var byteVal = 0;
      for (var k = 0; k < 8; k++) byteVal = (byteVal << 1) | bits[b + k];
      dataCws.push(byteVal);
    }
    var padBytes = [0xec, 0x11];
    var padIdx = 0;
    while (dataCws.length < totalDataCws) {
      dataCws.push(padBytes[padIdx % 2]);
      padIdx++;
    }

    // Split into RS blocks & interleave
    var dataBlocks = [];
    var ecBlocks = [];
    var offset = 0;
    for (var b1 = 0; b1 < g1Count; b1++) {
      var blk1 = dataCws.slice(offset, offset + g1Data);
      offset += g1Data;
      dataBlocks.push(blk1);
      ecBlocks.push(rsRemainder(blk1, ecPerBlock));
    }
    for (var b2 = 0; b2 < g2Count; b2++) {
      var blk2 = dataCws.slice(offset, offset + g2Data);
      offset += g2Data;
      dataBlocks.push(blk2);
      ecBlocks.push(rsRemainder(blk2, ecPerBlock));
    }

    var interleaved = [];
    var maxDataLen = Math.max(g1Data, g2Data);
    for (var d = 0; d < maxDataLen; d++) {
      for (var bi = 0; bi < dataBlocks.length; bi++) {
        if (d < dataBlocks[bi].length) interleaved.push(dataBlocks[bi][d]);
      }
    }
    for (var e = 0; e < ecPerBlock; e++) {
      for (var bj = 0; bj < ecBlocks.length; bj++) {
        interleaved.push(ecBlocks[bj][e]);
      }
    }
    return interleaved;
  }

  function formatBits(mask) {
    // EC Level M = 00
    var data = (0x0 << 3) | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
    return ((data << 10) | rem) ^ 0x5412;
  }

  function versionBits(version) {
    var rem = version;
    for (var i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >>> 11) * 0x1f25);
    return (version << 12) | rem;
  }

  function createBaseMatrix(version) {
    var size = version * 4 + 17;
    var modules = [];
    var isFunc = [];
    for (var r = 0; r < size; r++) {
      modules.push(new Uint8Array(size));
      isFunc.push(new Uint8Array(size));
    }

    function setFunc(r, c, val) {
      if (r >= 0 && r < size && c >= 0 && c < size) {
        modules[r][c] = val ? 1 : 0;
        isFunc[r][c] = 1;
      }
    }

    // Finder patterns + 1-module white separator
    function placeFinder(top, left) {
      for (var dr = -1; dr <= 7; dr++) {
        for (var dc = -1; dc <= 7; dc++) {
          var r = top + dr, c = left + dc;
          if (r < 0 || r >= size || c < 0 || c >= size) continue;
          var inOuter = dr >= 0 && dr <= 6 && dc >= 0 && dc <= 6;
          var onBorder = dr === 0 || dr === 6 || dc === 0 || dc === 6;
          var inCenter = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
          setFunc(r, c, inOuter && (onBorder || inCenter));
        }
      }
    }
    placeFinder(0, 0);
    placeFinder(0, size - 7);
    placeFinder(size - 7, 0);

    // Timing patterns
    for (var i = 8; i < size - 8; i++) {
      setFunc(6, i, i % 2 === 0);
      setFunc(i, 6, i % 2 === 0);
    }

    // Alignment patterns (skip only the 3 finder-pattern corners, NOT timing-pattern centers!)
    var centers = ALIGNMENT[version];
    for (var ai = 0; ai < centers.length; ai++) {
      for (var aj = 0; aj < centers.length; aj++) {
        var last = centers.length - 1;
        if ((ai === 0 && aj === 0) || (ai === 0 && aj === last) || (ai === last && aj === 0)) {
          continue;
        }
        var cr = centers[ai], cc = centers[aj];
        for (var dr = -2; dr <= 2; dr++) {
          for (var dc = -2; dc <= 2; dc++) {
            var d = Math.max(Math.abs(dr), Math.abs(dc));
            setFunc(cr + dr, cc + dc, d === 0 || d === 2);
          }
        }
      }
    }

    // Reserve format information areas + dark module
    for (var f = 0; f <= 8; f++) {
      if (f !== 6) {
        setFunc(8, f, false);
        setFunc(f, 8, false);
      }
    }
    for (var f2 = 0; f2 < 8; f2++) {
      setFunc(8, size - 1 - f2, false);
      if (f2 < 7) setFunc(size - 1 - f2, 8, false);
    }
    setFunc(size - 8, 8, true);

    // Version info for v >= 7
    if (version >= 7) {
      var vbits = versionBits(version);
      for (var vb = 0; vb < 18; vb++) {
        var bit = ((vbits >>> vb) & 1) === 1;
        var vr = Math.floor(vb / 3);
        var vc = size - 11 + (vb % 3);
        setFunc(vr, vc, bit);
        setFunc(vc, vr, bit);
      }
    }

    return { size: size, modules: modules, isFunc: isFunc };
  }

  function drawFormat(modules, size, mask) {
    var bits = formatBits(mask);
    // Around top-left finder
    for (var i = 0; i <= 5; i++) modules[8][i] = (bits >>> (14 - i)) & 1;
    modules[8][7] = (bits >>> 8) & 1;
    modules[8][8] = (bits >>> 7) & 1;
    modules[7][8] = (bits >>> 6) & 1;
    for (var j = 9; j < 15; j++) modules[14 - j][8] = (bits >>> (14 - j)) & 1;
    // Split copy (bottom-left vertical + top-right horizontal)
    for (var k = 0; k < 7; k++) modules[size - 1 - k][8] = (bits >>> (14 - k)) & 1;
    for (var m = 0; m < 8; m++) modules[8][size - 8 + m] = (bits >>> (7 - m)) & 1;
  }

  function placeData(modules, isFunc, size, codewords) {
    var bitIdx = 0;
    var totalBits = codewords.length * 8;
    var upward = true;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (var step = 0; step < size; step++) {
        var r = upward ? size - 1 - step : step;
        for (var dx = 0; dx < 2; dx++) {
          var c = right - dx;
          if (!isFunc[r][c]) {
            var bit = 0;
            if (bitIdx < totalBits) {
              bit = (codewords[bitIdx >>> 3] >>> (7 - (bitIdx & 7))) & 1;
              bitIdx++;
            }
            modules[r][c] = bit;
          }
        }
      }
      upward = !upward;
    }
  }

  function maskBit(mask, r, c) {
    switch (mask) {
      case 0: return ((r + c) % 2) === 0;
      case 1: return (r % 2) === 0;
      case 2: return (c % 3) === 0;
      case 3: return ((r + c) % 3) === 0;
      case 4: return ((Math.floor(r / 2) + Math.floor(c / 3)) % 2) === 0;
      case 5: return ((r * c) % 2) + ((r * c) % 3) === 0;
      case 6: return ((((r * c) % 2) + ((r * c) % 3)) % 2) === 0;
      case 7: return ((((r + c) % 2) + ((r * c) % 3)) % 2) === 0;
      default: return false;
    }
  }

  function penaltyScore(modules, size) {
    var score = 0;
    // N1: 5+ adjacent same-color modules in row/col
    for (var r = 0; r < size; r++) {
      var runColor = modules[r][0], runLen = 1;
      for (var c = 1; c < size; c++) {
        if (modules[r][c] === runColor) {
          runLen++;
          if (runLen === 5) score += 3;
          else if (runLen > 5) score += 1;
        } else {
          runColor = modules[r][c];
          runLen = 1;
        }
      }
    }
    for (var c2 = 0; c2 < size; c2++) {
      var runColor2 = modules[0][c2], runLen2 = 1;
      for (var r2 = 1; r2 < size; r2++) {
        if (modules[r2][c2] === runColor2) {
          runLen2++;
          if (runLen2 === 5) score += 3;
          else if (runLen2 > 5) score += 1;
        } else {
          runColor2 = modules[r2][c2];
          runLen2 = 1;
        }
      }
    }
    // N2: 2x2 blocks
    for (var br = 0; br < size - 1; br++) {
      for (var bc = 0; bc < size - 1; bc++) {
        var v = modules[br][bc];
        if (v === modules[br][bc + 1] && v === modules[br + 1][bc] && v === modules[br + 1][bc + 1]) {
          score += 3;
        }
      }
    }
    // N3: finder-like 1:1:3:1:1 patterns
    function hasPattern(arr) {
      var hits = 0;
      for (var i = 0; i <= arr.length - 11; i++) {
        var p1 = arr[i] && !arr[i+1] && arr[i+2] && arr[i+3] && arr[i+4] && !arr[i+5] && arr[i+6] && !arr[i+7] && !arr[i+8] && !arr[i+9] && !arr[i+10];
        var p2 = !arr[i] && !arr[i+1] && !arr[i+2] && !arr[i+3] && arr[i+4] && !arr[i+5] && arr[i+6] && arr[i+7] && arr[i+8] && !arr[i+9] && arr[i+10];
        if (p1 || p2) hits++;
      }
      return hits;
    }
    for (var pr = 0; pr < size; pr++) score += hasPattern(modules[pr]) * 40;
    for (var pc = 0; pc < size; pc++) {
      var col = new Uint8Array(size);
      for (var pr2 = 0; pr2 < size; pr2++) col[pr2] = modules[pr2][pc];
      score += hasPattern(col) * 40;
    }
    // N4: dark module balance
    var dark = 0;
    for (var dr = 0; dr < size; dr++) {
      for (var dc = 0; dc < size; dc++) dark += modules[dr][dc];
    }
    var k = Math.floor(Math.abs(dark * 20 - size * size * 10) / (size * size));
    score += k * 10;
    return score;
  }

  function encodeMatrix(text) {
    var bytes = utf8Bytes(String(text));
    var version = chooseVersion(bytes.length);
    var codewords = buildCodewords(bytes, version);
    var base = createBaseMatrix(version);
    placeData(base.modules, base.isFunc, base.size, codewords);

    var bestMask = 0;
    var bestScore = Infinity;
    var bestModules = null;

    for (var mask = 0; mask < 8; mask++) {
      var candidate = base.modules.map(function (row) { return new Uint8Array(row); });
      for (var r = 0; r < base.size; r++) {
        for (var c = 0; c < base.size; c++) {
          if (!base.isFunc[r][c] && maskBit(mask, r, c)) {
            candidate[r][c] ^= 1;
          }
        }
      }
      drawFormat(candidate, base.size, mask);
      var sc = penaltyScore(candidate, base.size);
      if (sc < bestScore) {
        bestScore = sc;
        bestMask = mask;
        bestModules = candidate;
      }
    }

    return {
      version: version,
      mask: bestMask,
      size: base.size,
      modules: bestModules,
    };
  }

  function toSvg(text, options) {
    var opts = options || {};
    var quiet = typeof opts.quietZone === 'number' ? opts.quietZone : 4;
    var dark = opts.darkColor || '#0F172A';
    var light = opts.lightColor || '#FFFFFF';
    var label = opts.ariaLabel || ('QR code for ' + text);
    var qr = encodeMatrix(text);
    var total = qr.size + quiet * 2;
    var d = [];
    for (var r = 0; r < qr.size; r++) {
      var c = 0;
      while (c < qr.size) {
        if (qr.modules[r][c]) {
          var start = c;
          while (c < qr.size && qr.modules[r][c]) c++;
          d.push('M' + (start + quiet) + ',' + (r + quiet) + 'h' + (c - start) + 'v1h-' + (c - start) + 'z');
        } else {
          c++;
        }
      }
    }
    var safeLabel = String(label)
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    return (
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + total + ' ' + total + '"' +
      ' role="img" aria-label="' + safeLabel + '" shape-rendering="crispEdges">' +
      '<rect width="' + total + '" height="' + total + '" fill="' + light + '"/>' +
      '<path fill="' + dark + '" d="' + d.join('') + '"/>' +
      '</svg>'
    );
  }

  var api = { encodeMatrix: encodeMatrix, toSvg: toSvg };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.PacerQR = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
