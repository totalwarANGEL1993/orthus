package twa.siedelwood.s5.questeditor.models.parameter;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
public class BooleanParameterImpl implements BooleanParamater
{
	protected String type;
	
	protected Boolean value;

	@Override
	public void setValue(final Object value)
	{
		this.value = (Boolean) value;
	}
}
