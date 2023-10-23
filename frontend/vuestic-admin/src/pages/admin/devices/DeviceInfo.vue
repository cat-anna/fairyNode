<template>
    <br/>
    <va-card>
        <va-card-title> {{ t('deviceInfo.title') }} </va-card-title>
        <va-card-content>
            <va-tabs v-model="activeTabName" grow>
                <template #tabs>
                    <va-tab name="DeviceInfoNodesTab"> {{ t('deviceInfo.nodes.tabTitle') }} </va-tab>
                    <va-tab name="DeviceInfoSoftwareTab"> {{ t('deviceInfo.software.tabTitle') }} </va-tab>
                </template>
            </va-tabs>
        </va-card-content>
    </va-card>
    <va-separator />
    <DeviceInfoNodes v-if="activeTabName == 'DeviceInfoNodesTab'" :device_id="device_id" />
    <DeviceInfoSoftware v-if="activeTabName == 'DeviceInfoSoftwareTab'" :device_id="device_id" />
</template>

<style lang="scss">
.va-tabs__tabs {
    height: 100%;
}
</style>

<script lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'

import DeviceInfoNodes from './DeviceInfoNodes.vue'
import DeviceInfoSoftware from './DeviceInfoSoftware.vue'

export default {
    components: {
        DeviceInfoNodes,
        DeviceInfoSoftware,
    },
    setup() {
        const route = useRoute()
        const device_id = ref(route.params.device_id as string)

        const { t } = useI18n()
        return { t, device_id }
    },
    data() {
        return {
            activeTabName: ref("DeviceInfoNodesTab"),
        }
    },
    beforeRouteUpdate(to, from, next) {
        this.device_id = to.params.device_id as string
        next()
    },

    mounted() {
        this.device_id = this.$route.params.device_id as string
    },
    unmounted() { },
    methods: { }
}
</script>

<style lang="scss">
  .va-tabs__tabs {
    height: 100%;
  }
</style>
