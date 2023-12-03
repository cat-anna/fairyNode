import { RestServiceBase } from './RestServiceBase'

export interface StatsContent {
  table: string[]
}

export declare type StatsTableEntry = string | number

export interface StatsTable {
  title?: string
  tag?: string
  header: string[]
  data: StatsTableEntry[][]
}

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
}

export default new StatusService()
