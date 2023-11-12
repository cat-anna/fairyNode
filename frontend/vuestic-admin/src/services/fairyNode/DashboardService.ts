
import http from "./http-common"
import {GenericResult} from "./http-common";

export interface DeviceEntry {
    name: string
    device_id: string
    hardware_id: string
}

export interface SummaryDeviceEntry extends DeviceEntry {
    status: string
    errors: number
    uptime: number
}

export interface DeviceNodeProperty {
    name: string
    id: string
    global_id: string
    property_id: string
    datatype: string
    value: string
    unit: string
    retained: boolean
    settable: boolean
    timestamp: number
}

export interface DeviceNode {
    name: string
    id: string
    global_id: string
    properties: DeviceNodeProperty[]
}

export declare type PropertyTypes = boolean | number | string;


export interface ChartSeriesSourceInfo {
    global_id: string
    device: string
}
export interface ChartSeriesInfo {
    name: string
    unit: string
    values: ChartSeriesSourceInfo[]
}

export class DashboardService {
    get_json(url: string) { return http.get_json("/dashboard" + url) }
    post_json(url: string, data: object) { return http.post_json("/dashboard" + url, data) }

    summary(): Promise<SummaryDeviceEntry[]> { return this.get_json("/summary") }

    getStatusColor(status: string) : string {
        if (status === 'ready') { return 'success' }
        if (status === 'init') { return 'warning' }
        return 'danger'
    }
}

export default new DashboardService()
