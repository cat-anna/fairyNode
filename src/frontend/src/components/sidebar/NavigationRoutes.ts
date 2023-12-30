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
        name: 'deviceInfo',
        rawDisplayName: e.name,
        params: {
          deviceId: e.device_id,
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
    },
    {
      name: 'devices',
      displayName: 'menu.devices',
      meta: {
        icon: 'vuestic-iconset-ui-elements',
      },
      childrenFunc: getDevicesRoutes,
    },
    {
      name: 'rules',
      displayName: 'menu.rules',
      meta: {
        icon: 'vuestic-iconset-components',
      },
      children: [
        {
          name: 'state',
          displayName: 'rules.state.title',
        },
      ],
    },
    {
      name: 'server',
      displayName: 'menu.server',
      meta: {
        icon: 'material-icons-kitchen',
      },
      children: [
        {
          name: 'debug_info',
          displayName: 'server.debug.title',
        },
      ],
    },
  ] as INavigationRoute[],
}
