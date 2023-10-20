<template>
    <div class="markup-tables flex">
        <va-card>
            <va-card-title>{{ t('tables.stripedHoverable') }}</va-card-title>
            <va-card-content>
                <div class="table-wrapper">
                    <table class="va-table va-table--striped va-table--hoverable">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Status</th>
                                <th>Error</th>
                                <th>Uptime</th>
                                <!-- <th>Country</th> -->
                            </tr>
                        </thead>

                        <tbody>
                            <tr v-for="device in deviceData" :key="device.id">
                                <td>
                                    <router-link style="text-decoration: none; color: inherit;" :to="{ path: '/admin/devices/' + device.id , params: { id: device.id } }">
                                        {{ device.name }}
                                    </router-link>
                                </td>
                                <td><va-badge :text="device.status" :color="getStatusColor(device.status)" /></td>
                                <td><va-badge :text="device.errors" color="danger" v-if="device.errors > 0" /></td>
                                <td>{{ formatSeconds(device.uptime) }}</td>
                                <!-- <td>{{ user.country }}</td> -->
                            </tr>
                        </tbody>
                    </table>
                </div>
            </va-card-content>
        </va-card>
    </div>
</template>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import deviceService from '../../../services/fairyNode/DeviceService'
import { SummaryDeviceEntry } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'

export default {
    deviceService,
    formatting,

    setup() {
        const { t } = useI18n()
        return { t }
    },
    data() {
        return {
            deviceData: Array<SummaryDeviceEntry>(),
            timerId: 0,
        }
    },
    mounted() {
        this.getData()
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 5 * 1000)
        }
    },
    unmounted() {
        if (this.timerId != 0) {
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },

    methods: {
        getStatusColor(v: string) { return deviceService.getStatusColor(v) },
        formatSeconds(v: number) { return formatting.formatSeconds(v) },

        getData() {
            deviceService.summary().then(data => this.deviceData = data)
        }
    },
}
</script>

<style lang="scss">
.markup-tables {
    .table-wrapper {
        overflow: auto;
    }

    .va-table {
        width: 100%;
    }
}
</style>
