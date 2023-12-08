import { defineStore } from 'pinia'

export interface ChartDesc {
  name: string
  seriesId: string[]
}

export const useGlobalStore = defineStore('global', {
  state: () => ({
    isSidebarMinimized: false,
    userName: 'Admin',
    currentTheme: 'dark',

    addedCharts: new Array<ChartDesc>(),
    chartDuration: 12 * 60 * 60,
  }),
  actions: {
    toggleSidebar() {
      this.isSidebarMinimized = !this.isSidebarMinimized
    },

    changeUserName(userName: string) {
      this.userName = userName
    },

    changeCurrentTheme(theme: string) {
      this.currentTheme = theme
    },

    setAddedCharts(lst: ChartDesc[]) {
      this.addedCharts = lst
    },
    setChartDuration(chartDuration: number) {
      this.chartDuration = chartDuration
    },
  },
  persist: {
    storage: localStorage,
  },
})
