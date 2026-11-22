export namespace model {
	
	export class ImportResult {
	    added: number;
	    skipped: number;
	    errors: string[];
	
	    static createFrom(source: any = {}) {
	        return new ImportResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.added = source["added"];
	        this.skipped = source["skipped"];
	        this.errors = source["errors"];
	    }
	}
	export class LatencyResult {
	    avgMs: number;
	    jitterMs: number;
	    minMs: number;
	    maxMs: number;
	    samples: number;
	
	    static createFrom(source: any = {}) {
	        return new LatencyResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.avgMs = source["avgMs"];
	        this.jitterMs = source["jitterMs"];
	        this.minMs = source["minMs"];
	        this.maxMs = source["maxMs"];
	        this.samples = source["samples"];
	    }
	}
	export class LogEntry {
	    time: string;
	    level: string;
	    message: string;
	
	    static createFrom(source: any = {}) {
	        return new LogEntry(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.time = source["time"];
	        this.level = source["level"];
	        this.message = source["message"];
	    }
	}
	export class Server {
	    id: string;
	    name: string;
	    protocol: string;
	    type: string;
	    host: string;
	    port: number;
	    uri: string;
	    outbound: number[];
	    source: string;
	    subUrl?: string;
	    subName?: string;
	    addedAt: number;
	    ping: number;
	
	    static createFrom(source: any = {}) {
	        return new Server(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.protocol = source["protocol"];
	        this.type = source["type"];
	        this.host = source["host"];
	        this.port = source["port"];
	        this.uri = source["uri"];
	        this.outbound = source["outbound"];
	        this.source = source["source"];
	        this.subUrl = source["subUrl"];
	        this.subName = source["subName"];
	        this.addedAt = source["addedAt"];
	        this.ping = source["ping"];
	    }
	}
	export class Settings {
	    mode: string;
	    killSwitch: boolean;
	    blockLan: boolean;
	    blockBt: boolean;
	    setSystemProxy: boolean;
	    dns: string;
	    autostart: boolean;
	    startMinimized: boolean;
	    closeToTray: boolean;
	    hotkeyEnabled: boolean;
	    logLevel: string;
	    proxyPort: number;
	    strictRoute: boolean;
	    selectedServer: string;
	    lastMode: string;
	    autoConnect: boolean;
	    fastestServer: boolean;
	    customDNS: string;
	    bypassDomains: string;
	    blockAds: boolean;
	    disableIPv6: boolean;
	    mtu: number;
	    udpBlock: boolean;
	
	    static createFrom(source: any = {}) {
	        return new Settings(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.mode = source["mode"];
	        this.killSwitch = source["killSwitch"];
	        this.blockLan = source["blockLan"];
	        this.blockBt = source["blockBt"];
	        this.setSystemProxy = source["setSystemProxy"];
	        this.dns = source["dns"];
	        this.autostart = source["autostart"];
	        this.startMinimized = source["startMinimized"];
	        this.closeToTray = source["closeToTray"];
	        this.hotkeyEnabled = source["hotkeyEnabled"];
	        this.logLevel = source["logLevel"];
	        this.proxyPort = source["proxyPort"];
	        this.strictRoute = source["strictRoute"];
	        this.selectedServer = source["selectedServer"];
	        this.lastMode = source["lastMode"];
	        this.autoConnect = source["autoConnect"];
	        this.fastestServer = source["fastestServer"];
	        this.customDNS = source["customDNS"];
	        this.bypassDomains = source["bypassDomains"];
	        this.blockAds = source["blockAds"];
	        this.disableIPv6 = source["disableIPv6"];
	        this.mtu = source["mtu"];
	        this.udpBlock = source["udpBlock"];
	    }
	}
	export class SpeedResult {
	    downloadMbps: number;
	    uploadMbps: number;
	    latencyMs: number;
	    jitterMs: number;
	    minMs: number;
	    maxMs: number;
	    url: string;
	
	    static createFrom(source: any = {}) {
	        return new SpeedResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.downloadMbps = source["downloadMbps"];
	        this.uploadMbps = source["uploadMbps"];
	        this.latencyMs = source["latencyMs"];
	        this.jitterMs = source["jitterMs"];
	        this.minMs = source["minMs"];
	        this.maxMs = source["maxMs"];
	        this.url = source["url"];
	    }
	}
	export class Status {
	    connected: boolean;
	    connecting: boolean;
	    switching: boolean;
	    mode: string;
	    serverId: string;
	    serverName: string;
	    protocol: string;
	    startedAt: number;
	    upload: number;
	    download: number;
	    uploadTot: number;
	    downloadTot: number;
	    assignedIp: string;
	    proxyAddr: string;
	    error: string;
	
	    static createFrom(source: any = {}) {
	        return new Status(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.connected = source["connected"];
	        this.connecting = source["connecting"];
	        this.switching = source["switching"];
	        this.mode = source["mode"];
	        this.serverId = source["serverId"];
	        this.serverName = source["serverName"];
	        this.protocol = source["protocol"];
	        this.startedAt = source["startedAt"];
	        this.upload = source["upload"];
	        this.download = source["download"];
	        this.uploadTot = source["uploadTot"];
	        this.downloadTot = source["downloadTot"];
	        this.assignedIp = source["assignedIp"];
	        this.proxyAddr = source["proxyAddr"];
	        this.error = source["error"];
	    }
	}
	export class Subscription {
	    url: string;
	    name: string;
	    count: number;
	    lastSync: number;
	
	    static createFrom(source: any = {}) {
	        return new Subscription(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.url = source["url"];
	        this.name = source["name"];
	        this.count = source["count"];
	        this.lastSync = source["lastSync"];
	    }
	}

}

