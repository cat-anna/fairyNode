
import { DeviceNodeProperty } from "./DeviceService"

class DataTypes {

    public isBooleanProperty(property: DeviceNodeProperty): boolean {
        return property.datatype == 'boolean'
    }
    public parseBooleanProperty(value: string): boolean {
        if(value == "true")
            return true
        else
            return false
    }

    public isNumberProperty(property: DeviceNodeProperty): boolean {
        return property.datatype == 'number' || property.datatype == 'float'
    }
    public parseNumberProperty(value: string): number {
        return Number.parseFloat(value)
    }

    public isStringProperty(property: DeviceNodeProperty): boolean {
        return property.datatype == 'string'
    }
}

export default new DataTypes();
