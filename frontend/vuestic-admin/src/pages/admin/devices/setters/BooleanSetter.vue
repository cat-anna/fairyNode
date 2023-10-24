
<template>
    <OrbitSpinner v-if="!idle" :size="16" />
    <va-button v-if="idle && device_id && node_id && prop_id" preset="plain" size="small" @click="onToggle"> {{ t('deviceInfo.setter.toggle') }} </va-button>
</template>

<style>
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import deviceService from '../../../../services/fairyNode/DeviceService'
import { OrbitSpinner } from 'epic-spinners'

export default {
    components: {
        OrbitSpinner,
    },
    props: {
        device_id: String,
        node_id: String,
        prop_id: String,
        value: Boolean
    },
    emits: [ "changed" ],
    setup(Properties, { emit }) {
        const { t } = useI18n()
        return { t, emit }
    },
    data() {
        return {
            idle: true
        }
    },
    methods: {
        onToggle() {
            this.idle = false
            if (this.device_id && this.node_id && this.prop_id) {
                deviceService.setProperty(this.device_id, this.node_id, this.prop_id, !this.value)
                    .finally( () => {
                        this.idle = true
                        this.emit('changed')
                    })
            }
        }
    }
}
</script>

