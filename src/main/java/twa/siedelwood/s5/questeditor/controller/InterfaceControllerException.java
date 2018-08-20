
package twa.siedelwood.s5.questeditor.controller;

@SuppressWarnings("serial")
public class InterfaceControllerException extends Exception
{
	public InterfaceControllerException()
	{
		super();
	}

	public InterfaceControllerException(
		final String message, final Throwable cause, final boolean enableSuppression, final boolean writableStackTrace
	)
	{
		super(message, cause, enableSuppression, writableStackTrace);
	}

	public InterfaceControllerException(final String message, final Throwable cause)
	{
		super(message, cause);
	}

	public InterfaceControllerException(final String message)
	{
		super(message);
	}

	public InterfaceControllerException(final Throwable cause)
	{
		super(cause);
	}
}
