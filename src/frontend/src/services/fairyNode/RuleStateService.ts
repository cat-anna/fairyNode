import { RestServiceBase } from './RestServiceBase'
import { useGlobalStore } from '../../stores/global-store'
import { GenericResult } from './http-common'

const globalStore = useGlobalStore()

export interface GraphUrl {
  url: string
}

export interface RuleStatus {
  id: string
  name: string
}

export interface StatusInfo {
  rules: Array<RuleStatus>
}

export interface RuleDetails {
  name: string
}

export interface CreateRuleResult extends GenericResult {
  id?: string
}

export interface CodeError {
  line?: number
  message?: string
  error?: string
}

export interface CodeResult extends GenericResult {
  validation_success: boolean
  errors: Array<CodeError>
}

export class StatusService extends RestServiceBase {
  constructor() {
    super('rule-state')
  }

  getRuleList(): Promise<StatusInfo> {
    return this.get_json('')
  }

  createRule(name: string): Promise<CreateRuleResult> {
    return this.post_json('/create', { name: name })
  }

  getRuleGraphUrl(id: string): Promise<GraphUrl> {
    return this.get_json('/rule/' + id + '/graph/url?colors=' + globalStore.currentTheme)
  }

  getRuleDetails(id: string): Promise<RuleDetails> {
    return this.get_json('/rule/' + id + '/details')
  }

  deleteRule(id: string): Promise<GraphUrl> {
    return this.post_json('/rule/' + id + '/remove', {})
  }

  getRuleCode(id: string): Promise<string> {
    return this.get_text('/rule/' + id + '/code')
  }
  setRuleCode(id: string, code: string): Promise<CodeResult> {
    return this.post_text('/rule/' + id + '/code', code)
  }

  validateCode(code: string): Promise<CodeResult> {
    return this.post_text('/validate', code)
  }
}

export default new StatusService()
