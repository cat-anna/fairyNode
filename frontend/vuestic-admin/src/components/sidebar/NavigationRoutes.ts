import deviceService from '../../services/fairyNode/DeviceService'

import { RouteParams } from 'vue-router'

export interface INavigationRoute {
  name: string
  displayName?: string
  rawDisplayName?: string
  meta: { icon: string }
  children?: INavigationRoute[]
  childrenFunc?: () => Promise<INavigationRoute[]>
  params: RouteParams
}

async function getDevicesRoutes(): Promise<INavigationRoute[]> {
  return deviceService.list().then(function (data) {
    const r: INavigationRoute[] = []

    data.forEach(function (e) {
      r.push({
        name: 'device_info',
        rawDisplayName: e.name,
        params: {
          device_id: e.device_id,
        },
        meta: { icon: '' },
      } as INavigationRoute)
    })

    r.sort(function (a: INavigationRoute, b: INavigationRoute) {
      return (a.rawDisplayName || a.name).toLowerCase().localeCompare((b.rawDisplayName || b.name).toLowerCase())
    })

    return r
  })
}

export default {
  root: {
    name: '/',
    displayName: 'navigationRoutes.home',
  },
  routes: [
    {
      name: 'dashboard',
      displayName: 'menu.dashboard',
      meta: {
        icon: 'vuestic-iconset-dashboard',
      },
    },
    {
      name: 'charts',
      displayName: 'menu.charts',
      meta: {
        icon: 'vuestic-iconset-graph',
      },
      // childrenFunc: getDevicesRoutes,
    },
    {
      name: 'devices',
      displayName: 'menu.devices',
      meta: {
        icon: 'vuestic-iconset-ui-elements',
      },
      childrenFunc: getDevicesRoutes,
    },
  ] as INavigationRoute[],
}
