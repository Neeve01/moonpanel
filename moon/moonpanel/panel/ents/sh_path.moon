import Rect from Moonpanel

circ = Material "moonpanel/circ128.png"
hexagon = Material "moonpanel/hexagon.png"

class PathEntity
    new: (@parent) =>
    checkSolution: (@areaData) =>
        return true

    render: =>
    renderEntity: =>
        if @entity
            @entity\render!

    getClassName: =>
        return @__class.__name

    populatePathMap: (pathMap) => 

class Hexagon extends PathEntity
    new: (@parent, defs) =>
        @attributes = {
            color: Moonpanel.Color.Black
        }

    checkSolution: (areaData) =>
        return @parent.solutionData.traced
 
    render: =>
        bounds = @parent.bounds

        w = math.min bounds.width, bounds.height

        surface.SetMaterial hexagon
        surface.DrawTexturedRect bounds.x + (bounds.width / 2) - (w / 2), 
            bounds.y + (bounds.height / 2) - (w / 2), w, w
        draw.NoTexture!

class VBroken extends PathEntity
    overridesRender: true
    background: true
    populatePathMap: (pathMap) =>
        gap = @parent.bounds.height * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        height = @parent.bounds.height / 2 - gap / 2

        topIntersection = @parent\getTop!
        bottomIntersection = @parent\getBottom!

        topNode = topIntersection and topIntersection.pathMapNode
        bottomNode = bottomIntersection and bottomIntersection.pathMapNode

        if topNode and bottomNode
            nodeA = {
                x: topNode.x
                y: topNode.y + 0.25
                screenX: topNode.screenX
                screenY: topNode.screenY + height
                lowPriority: true
                neighbors: { topNode }
            }
            table.insert topNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: bottomNode.x
                y: bottomNode.y - 0.25
                screenX: bottomNode.screenX
                screenY: bottomNode.screenY - height
                lowPriority: true
                neighbors: { bottomNode }
            }
            table.insert bottomNode.neighbors, nodeB
            table.insert pathMap, nodeB
        return true

    render: =>
        gap = @parent.bounds.height * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        height = @parent.bounds.height / 2 - gap / 2
        
        surface.SetDrawColor @parent.tile.colors.untraced
        surface.DrawRect @parent.bounds.x, @parent.bounds.y, @parent.bounds.width, height
        surface.DrawRect @parent.bounds.x, @parent.bounds.y + gap + height, @parent.bounds.width, height

        return true

class HBroken extends PathEntity
    overridesRender: true
    background: true
    populatePathMap: (pathMap) =>
        gap = @parent.bounds.width * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        width = @parent.bounds.width / 2 - gap / 2

        leftIntersection = @parent\getLeft!
        rightIntersection = @parent\getRight!

        leftNode = leftIntersection and leftIntersection.pathMapNode
        rightNode = rightIntersection and rightIntersection.pathMapNode

        if leftNode and rightNode
            nodeA = {
                x: leftNode.x + 0.25
                y: leftNode.y
                screenX: leftNode.screenX + width
                screenY: leftNode.screenY
                lowPriority: true
                neighbors: { leftNode }
            }
            table.insert leftNode.neighbors, nodeA
            table.insert pathMap, nodeA

            nodeB = {
                x: rightNode.x - 0.25
                y: rightNode.y
                screenX: rightNode.screenX - width
                screenY: rightNode.screenY
                lowPriority: true
                neighbors: { rightNode }
            }
            table.insert rightNode.neighbors, nodeB
            table.insert pathMap, nodeB

        return true

    render: =>
        gap = @parent.bounds.width * (@parent.tile.tileData.Dimensions.DisjointLength or 0.25)
        width = @parent.bounds.width / 2 - gap / 2
        
        surface.SetDrawColor @parent.tile.colors.untraced
        surface.DrawRect @parent.bounds.x, @parent.bounds.y, width, @parent.bounds.height
        surface.DrawRect @parent.bounds.x + gap + width, @parent.bounds.y, width, @parent.bounds.height
        
        return true

Moonpanel.Entities or= {}

Moonpanel.Entities.HPath = {
    [MOONPANEL_ENTITY_TYPES.HEXAGON]: Hexagon
    [MOONPANEL_ENTITY_TYPES.DISJOINT]: HBroken
}

Moonpanel.Entities.VPath = {
    [MOONPANEL_ENTITY_TYPES.HEXAGON]: Hexagon
    [MOONPANEL_ENTITY_TYPES.DISJOINT]: VBroken
}