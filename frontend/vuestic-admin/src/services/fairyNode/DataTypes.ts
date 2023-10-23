
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
}

export default new DataTypes();
