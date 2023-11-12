
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


export interface DeviceVariable {
    key: string
    value: string
}
export class DeviceService {
    get_json(url: string) { return http.get_json("/device" + url) }
    post_json(url: string, data: object) { return http.post_json("/device" + url, data) }

    list(): Promise<DeviceEntry[]> { return this.get_json("") }
    nodesSummary(device_id: string) : Promise<DeviceNode[]> { return this.get_json("/" + device_id + "/summary") }
    variables(device_id: string) : Promise<DeviceVariable[]> { return this.get_json("/" + device_id + "/variables") }

    setProperty(device_id: string, node_id: string, property_id: string, value: PropertyTypes) : Promise<GenericResult> {
        return this.post_json( "/" + device_id + "/property/" + node_id + "/" + property_id + "/set", { value: value })
    }

    getStatusColor(status: string) : string {
        if (status === 'ready') { return 'success' }
        if (status === 'init') { return 'warning' }
        return 'danger'
    }
}

export default new DeviceService()
