
import http from "./http-common";

export interface DeviceEntry {
    name: string;
    id: string;
}

export interface SummaryDeviceEntry extends DeviceEntry {
    status: string;
    errors: number;
    uptime: number;
}

export interface DeviceNodeProperty {
    name: string;
    id: string;
    global_id: string;
    property_id: string;
    datatype: string;
    value: string;
    unit: string;
    retained: boolean;
    settable: boolean;
    timestamp: number;
}

export interface DeviceNode {
    name: string;
    id: string;
    global_id: string;
    properties: Map<string, DeviceNodeProperty>
}

export class DeviceService {
    get_json(url:string) { return http.get_json("/device" + url); }

    summary(): Promise<SummaryDeviceEntry[]> { return this.get_json("/summary"); }
    list(): Promise<DeviceEntry[]> { return this.get_json("/list"); }

    nodesSummary(device_id: string) : Promise<Map<string,DeviceNode>> { return this.get_json("/nodes/"+device_id+"/summary"); }

    getStatusColor(status: string) : string {
        if (status === 'ready') { return 'success' }
        if (status === 'init') { return 'warning' }
        return 'danger'
    }
}

export default new DeviceService();
