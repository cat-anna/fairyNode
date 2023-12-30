import http from './http-common'
import { GenericResult as HttpGenericResult } from './http-common'

export declare type GenericResult = HttpGenericResult

export class RestServiceBase {
  protected get_json(url: string) {
    return http.get_json('/' + this.service_name + url)
  }
  protected get_text(url: string) {
    return http.get_text('/' + this.service_name + url)
  }
  protected post_json(url: string, data: object) {
    return http.post_json('/' + this.service_name + url, data)
  }
  protected post_text(url: string, data: string) {
    return http.post_text('/' + this.service_name + url, data)
  }
  constructor(service_name: string) {
    this.service_name = service_name
  }

  private service_name: string
}
