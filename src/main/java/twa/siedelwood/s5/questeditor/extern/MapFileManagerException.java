
package twa.siedelwood.s5.questeditor.extern;

@SuppressWarnings("serial")
public class MapFileManagerException extends Exception
{

	public MapFileManagerException()
	{
		super();
	}

	public MapFileManagerException(
		final String message, final Throwable cause, final boolean enableSuppression, final boolean writableStackTrace
	)
	{
		super(message, cause, enableSuppression, writableStackTrace);
	}

	public MapFileManagerException(final String message, final Throwable cause)
	{
		super(message, cause);
	}

	public MapFileManagerException(final String message)
	{
		super(message);
	}

	public MapFileManagerException(final Throwable cause)
	{
		super(cause);
	}

}
