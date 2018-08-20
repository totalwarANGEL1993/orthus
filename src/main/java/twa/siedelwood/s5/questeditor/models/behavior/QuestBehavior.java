package twa.siedelwood.s5.questeditor.models.behavior;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import twa.siedelwood.s5.questeditor.models.parameter.Parameter;

/**
 * Implementation of the behavior type.
 * @author totalwarANGEL
 *
 */
@Getter
@Setter
@AllArgsConstructor
public class QuestBehavior implements Behavior
{
    /**
     * Type of behavior.
     */
    protected String type;

    /**
     * Name of behavior.
     */
    protected String name;
    
    /**
     * List of arguments
     */
    protected List<Parameter> arguments;
}
