import { defineStore } from 'pinia'

export const useGlobalStore = defineStore('global', {
    state: () => ({
        isSidebarMinimized: false,
        userName: 'Admin',
        currentTheme: 'dark',
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
        }
    },
    persist: {
        storage: localStorage,
    }
})
