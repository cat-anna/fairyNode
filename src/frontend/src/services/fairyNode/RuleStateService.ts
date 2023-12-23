import { RestServiceBase } from './RestServiceBase'

export interface GraphUrl {
  url: string
}

import { useGlobalStore } from '../../stores/global-store'
const globalStore = useGlobalStore()

export class StatusService extends RestServiceBase {
  constructor() {
    super('rule-state')
  }

  getGraphUrl(id: string): Promise<GraphUrl> {
    return this.get_json('/rule/' + id + '/graph/url?colors=' + globalStore.currentTheme)
  }
}

export default new StatusService()
