import { RestServiceBase } from './RestServiceBase'

export interface StringStringPair {
  key: string
  value: string
}

export interface StatsContent {
  table: Array<StringStringPair>
  graph: Array<StringStringPair>
}

export declare type StatsTableEntry = string | number

export interface StatsTable {
  title?: string
  tag?: string
  header: string[]
  data: StatsTableEntry[][]
}

export interface GraphUrl {
  url: string
}

import { useGlobalStore } from '../../stores/global-store'
const globalStore = useGlobalStore()

export class StatusService extends RestServiceBase {
  constructor() {
    super('status')
  }

  getStatusContent(): Promise<StatsContent> {
    return this.get_json('')
  }

  getStatusTableList(): Promise<string[]> {
    return this.get_json('/table')
  }
  getStatusTable(id: string): Promise<StatsTable> {
    return this.get_json('/table/' + id)
  }

  getStatusGraphUrl(id: string): Promise<GraphUrl> {
    return this.get_json('/graph/' + id + '/url?colors=' + globalStore.currentTheme)
  }
  getStatusGraphText(id: string): Promise<string> {
    return this.get_text('/graph/' + id + '/text?colors=' + globalStore.currentTheme)
  }
}

export default new StatusService()
