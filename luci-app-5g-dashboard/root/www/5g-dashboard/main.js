// ===== DOM 缓存 =====
var $ = function(id) { return document.getElementById(id); };
var cache = {
  dlI: $('dl-i'), dlD: $('dl-d'), ulI: $('ul-i'), ulD: $('ul-d'),
  stDot: $('st-dot'), stTxt: $('st-txt'), tmp: $('v-temp'),
  vOp: $('v-op'), vMode: $('v-mode'), vDlbw: $('v-dlbw'), vUlbw: $('v-ulbw'),
  vQci: $('v-qci'), vCell: $('v-cell'), vIp4: $('v-ip4'), vIp6: $('v-ip6'),
  vRsrp: $('v-rsrp'), vSinr: $('v-sinr'), vRsrq: $('v-rsrq'),
  barRsrp: $('bar-rsrp'), barSinr: $('bar-sinr'), barRsrq: $('bar-rsrq'),
  gval: $('gval'), gpg: $('gpg'),
  vBand: $('v-band'), vBw: $('v-bw'), vArfcn: $('v-arfcn'), vPci: $('v-pci'),
  vMain: $('v-main'), vDiv: $('v-div'), vMimo1: $('v-mimo1'), vMimo2: $('v-mimo2'),
  sigBars: $('sig-bars').querySelectorAll('.bar'),
  cardSt: $('card-st')
};

// ===== 工具函数 =====
function safe(v, fallback) {
  if (v === null || v === undefined || v === '' || v === 'undefined' || v === 'null') {
    return fallback !== undefined ? fallback : '--';
  }
  return v;
}

function safeNum(v, fallback) {
  if (v === null || v === undefined || v === '' || v === '--' || v === 'undefined') {
    return fallback !== undefined ? fallback : 0;
  }
  var n = parseFloat(v);
  return isNaN(n) ? (fallback !== undefined ? fallback : 0) : n;
}

function splitSpeed(val) {
  var num = safeNum(val, 0);
  var s = num.toFixed(2);
  var parts = s.split('.');
  return { int: parts[0], dec: '.' + parts[1] };
}

// ===== 核心更新函数 =====
function updateDashboard(data) {
  if (!data || typeof data !== 'object') return;

  // 网络状态
  var connected = data.networkStatus === 'connected';
  cache.stDot.style.background = connected ? '#52C41A' : '#FF4D4F';
  cache.stTxt.textContent = connected ? '已连接互联网' : '未连接/无服务';

  // 速率
  var dl = splitSpeed(data.downloadSpeed);
  var ul = splitSpeed(data.uploadSpeed);
  cache.dlI.textContent = dl.int;
  cache.dlD.textContent = dl.dec;
  cache.ulI.textContent = ul.int;
  cache.ulD.textContent = ul.dec;

  // 温度
  var temp = safeNum(data.temperature, 0);
  cache.tmp.textContent = temp + ' °C';
  cache.tmp.style.color = temp > 65 ? '#FF4D4F' : temp > 50 ? '#FAAD14' : '';

  // 网络信息
  cache.vOp.textContent = safe(data.operator);
  cache.vMode.textContent = safe(data.networkMode);
  cache.vDlbw.textContent = safe(data.downloadBandwidth, '--') + ' Mbps';
  cache.vUlbw.textContent = safe(data.uploadBandwidth, '--') + ' Mbps';
  cache.vQci.textContent = safe(data.qci);
  cache.vCell.textContent = safe(data.cellId);
  cache.vIp4.textContent = safe(data.ipv4);
  cache.vIp6.textContent = safe(data.ipv6);
  cache.vIp6.title = safe(data.ipv6);

  // RSRP
  var rsrp = safeNum(data.rsrp, -130);
  var rsrpPct = Math.max(0, Math.min(100, ((rsrp + 130) / 70) * 100));
  var rsrpColor = rsrp >= -90 ? '#52C41A' : rsrp >= -105 ? '#FAAD14' : '#FF4D4F';
  cache.vRsrp.textContent = rsrp + ' dBm';
  cache.barRsrp.style.width = rsrpPct + '%';
  cache.barRsrp.style.backgroundColor = rsrpColor;

  // SINR
  var sinr = safeNum(data.sinr, -10);
  var sinrPct = Math.max(0, Math.min(100, ((sinr + 10) / 40) * 100));
  var sinrColor = sinr >= 13 ? '#52C41A' : sinr >= 0 ? '#FAAD14' : '#FF4D4F';
  cache.vSinr.textContent = sinr + ' dB';
  cache.barSinr.style.width = sinrPct + '%';
  cache.barSinr.style.backgroundColor = sinrColor;

  // RSRQ
  var rsrq = safeNum(data.rsrq, -25);
  var rsrqPct = Math.max(0, Math.min(100, ((rsrq + 25) / 15) * 100));
  var rsrqColor = rsrq >= -10 ? '#52C41A' : rsrq >= -15 ? '#FAAD14' : '#FF4D4F';
  cache.vRsrq.textContent = rsrq + ' dB';
  cache.barRsrq.style.width = rsrqPct + '%';
  cache.barRsrq.style.backgroundColor = rsrqColor;

  // 综合质量评分（NaN保护）
  var rsrpScore = 0, sinrScore = 0, totalScore = 0;
  if (!isNaN(rsrp) && rsrp !== 0) {
    rsrpScore = Math.max(0, Math.min(40, ((rsrp + 130) / 70) * 40));
  }
  if (!isNaN(sinr) && sinr !== 0) {
    sinrScore = Math.max(0, Math.min(60, ((sinr + 10) / 40) * 60));
  }
  totalScore = Math.floor(rsrpScore + sinrScore);
  if (isNaN(totalScore)) totalScore = 0;

  cache.gval.textContent = totalScore;
  var circumference = 339.292;
  var offset = circumference - (totalScore / 100) * circumference;
  cache.gpg.style.strokeDashoffset = offset;
  if (totalScore >= 70) { cache.gpg.style.stroke = '#52C41A'; cache.gval.style.color = '#262626'; }
  else if (totalScore >= 40) { cache.gpg.style.stroke = '#FA8C16'; cache.gval.style.color = '#262626'; }
  else { cache.gpg.style.stroke = '#FF4D4F'; cache.gval.style.color = '#FF4D4F'; }

  // 信号格
  var bars = cache.sigBars;
  var activeBars = 0;
  if (rsrp >= -80) activeBars = 5;
  else if (rsrp >= -90) activeBars = 4;
  else if (rsrp >= -100) activeBars = 3;
  else if (rsrp >= -110) activeBars = 2;
  else if (rsrp >= -120) activeBars = 1;
  for (var i = 0; i < bars.length; i++) {
    bars[i].className = 'bar b' + (i + 1);
    if (i < activeBars) {
      if (activeBars >= 4) bars[i].classList.add('a');
      else if (activeBars >= 2) bars[i].classList.add('w');
      else bars[i].classList.add('d');
    }
  }

  // 频段信息
  var bandVal = safe(data.band);
  cache.vBand.textContent = (bandVal !== '--' && bandVal !== '0') ? 'n' + bandVal : '--';
  cache.vBw.textContent = safe(data.bandwidth, '--') + ' MHz';
  cache.vArfcn.textContent = safe(data.arfcn);
  cache.vPci.textContent = safe(data.pci);

  // 天线分集
  cache.vMain.textContent = safe(data.antMain, '--') + (safe(data.antMain, '--') !== '--' ? ' dBm' : '');
  cache.vDiv.textContent = safe(data.antDiv, '--') + (safe(data.antDiv, '--') !== '--' ? ' dBm' : '');
  cache.vMimo1.textContent = safe(data.antMimo1, '--') + (safe(data.antMimo1, '--') !== '--' ? ' dBm' : '');
  cache.vMimo2.textContent = safe(data.antMimo2, '--') + (safe(data.antMimo2, '--') !== '--' ? ' dBm' : '');

  // 潮汐波浪
  var dlSpeed = safeNum(data.downloadSpeed, 0);
  var waveH, waveS;
  if (dlSpeed <= 0) { waveH = '-10%'; waveS = '10s'; }
  else if (dlSpeed < 100) { waveH = '20%'; waveS = '8s'; }
  else if (dlSpeed < 300) { waveH = '35%'; waveS = '5s'; }
  else if (dlSpeed < 500) { waveH = '50%'; waveS = '4s'; }
  else { waveH = '60%'; waveS = '3s'; }
  cache.cardSt.style.setProperty('--wh', waveH);
  cache.cardSt.style.setProperty('--ws', waveS);
}

// ===== Mock数据（本地调试用） =====
var MOCK_DATA = {
  networkStatus: 'connected',
  downloadSpeed: 156.78,
  uploadSpeed: 42.35,
  temperature: 43,
  operator: 'CHINA UNICOM',
  networkMode: 'NR5G-SA',
  downloadBandwidth: 1000,
  uploadBandwidth: 200,
  qci: 6,
  cellId: '820CB6188',
  ipv4: '10.65.73.153',
  ipv6: '2408:8956:1010:27c7:48dd:2b52:4821:b0f3',
  rsrp: -107,
  sinr: 1,
  rsrq: -11,
  band: 78,
  bandwidth: 100,
  arfcn: 633984,
  pci: 720,
  antMain: -116,
  antDiv: -107,
  antMimo1: -113,
  antMimo2: -113
};

// ===== 时钟 =====
function updateClock() {
  var n = new Date();
  var w = ['日','一','二','三','四','五','六'];
  $('dt').textContent = n.getFullYear() + '年' + (n.getMonth()+1) + '月' + n.getDate() + '日 星期' + w[n.getDay()] + ' ' +
    String(n.getHours()).padStart(2,'0') + ':' + String(n.getMinutes()).padStart(2,'0');
}
updateClock();
setInterval(updateClock, 1000);

// ===== 真实数据请求 =====
var API_URL = '/cgi-bin/get_5g_info';
var POLL_INTERVAL = 3000;

function fetchRouterData() {
  fetch(API_URL, { method: 'GET', cache: 'no-store' })
    .then(function(res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    })
    .then(function(data) {
      if (data && typeof data === 'object' && Object.keys(data).length > 0) {
        updateDashboard(data);
      } else {
        updateDashboard(MOCK_DATA);
      }
    })
    .catch(function(err) {
      console.warn('[5G Dashboard] API请求失败，使用Mock数据:', err.message);
      updateDashboard(MOCK_DATA);
    });
}

// 首次加载（先显示Mock，等API响应后覆盖）
updateDashboard(MOCK_DATA);
fetchRouterData();

// 轮询
setInterval(fetchRouterData, POLL_INTERVAL);
